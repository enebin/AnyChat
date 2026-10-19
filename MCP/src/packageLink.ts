import { execFileSync } from "node:child_process";
import { existsSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { project as openProject } from "xcode";
import { generatorSpec, productName } from "./project.js";

export type PackageSource =
  | { kind: "remote"; url: string; minimumVersion: string }
  | { kind: "local"; relativePath: string };

export type LinkPlan =
  | { status: "linked"; targetName: string; reusedReference: boolean; pbxproj: string }
  | { status: "alreadyLinked"; targetName: string }
  | { status: "chooseTarget"; candidates: string[] };

export type AddPackageResult =
  | Exclude<LinkPlan, { status: "linked" }>
  | { status: "linked"; targetName: string; reusedReference: boolean }
  | { status: "notFound" }
  | { status: "generated"; specFile: string }
  | { status: "invalid"; reason: string };

type Section = Record<string, Record<string, unknown> | string>;
type Reference = { value: string; comment?: string };

const applicationProductType = "com.apple.product-type.application";

/** Links the SDK product into one app target and returns the new file text, without writing it. */
export function planPackageLink(pbxprojPath: string, source: PackageSource, targetName?: string): LinkPlan {
  const xcodeProject = openProject(pbxprojPath).parseSync();
  const objects = xcodeProject.hash.project.objects;
  const targets = records(objects.PBXNativeTarget);
  const applications = targets.filter(([, target]) => unquote(target.productType) === applicationProductType);
  const matches = targetName === undefined ? applications : targets.filter(([, target]) => unquote(target.name) === targetName);
  if (matches.length !== 1) {
    const candidates = targetName === undefined && applications.length > 1 ? applications : targets;
    return { status: "chooseTarget", candidates: candidates.map(([, target]) => unquote(target.name)) };
  }

  const [, target] = matches[0]!;
  const linkedTargetName = unquote(target.name);
  const dependencies = section(objects, "XCSwiftPackageProductDependency");
  const productDependencies = (target.packageProductDependencies ?? []) as Reference[];
  if (productDependencies.some((dependency) => unquote(record(dependencies, dependency.value)?.productName) === productName)) {
    return { status: "alreadyLinked", targetName: linkedTargetName };
  }

  const id = () => xcodeProject.generateUuid();
  const [, rootProject] = records(objects.PBXProject)[0]!;
  const referenceSection = source.kind === "remote" ? "XCRemoteSwiftPackageReference" : "XCLocalSwiftPackageReference";
  const referenceComment = source.kind === "remote"
    ? `XCRemoteSwiftPackageReference "${repositoryName(source.url)}"`
    : `XCLocalSwiftPackageReference "${source.relativePath}"`;
  const existingReference = records(objects[referenceSection]).find(([, reference]) =>
    source.kind === "remote"
      ? normalizedURL(unquote(reference.repositoryURL)) === normalizedURL(source.url)
      : unquote(reference.relativePath) === source.relativePath
  );

  let referenceID = existingReference?.[0];
  if (referenceID === undefined) {
    referenceID = id();
    add(objects, referenceSection, referenceID, referenceComment, source.kind === "remote"
      ? {
          isa: referenceSection,
          repositoryURL: quote(source.url),
          requirement: { kind: "upToNextMajorVersion", minimumVersion: quote(source.minimumVersion) },
        }
      : { isa: referenceSection, relativePath: quote(source.relativePath) });
    rootProject.packageReferences = [...((rootProject.packageReferences ?? []) as Reference[]), { value: referenceID, comment: referenceComment }];
  }

  const dependencyID = id();
  add(objects, "XCSwiftPackageProductDependency", dependencyID, productName, {
    isa: "XCSwiftPackageProductDependency",
    package: referenceID,
    package_comment: referenceComment,
    productName,
  });
  target.packageProductDependencies = [...productDependencies, { value: dependencyID, comment: productName }];

  const buildFileID = id();
  const buildFileComment = `${productName} in Frameworks`;
  add(objects, "PBXBuildFile", buildFileID, buildFileComment, {
    isa: "PBXBuildFile",
    productRef: dependencyID,
    productRef_comment: productName,
  });
  const buildPhases = target.buildPhases as Reference[];
  let frameworksPhase = buildPhases.map((phase) => record(objects.PBXFrameworksBuildPhase, phase.value)).find(Boolean);
  if (frameworksPhase === undefined) {
    const phaseID = id();
    frameworksPhase = { isa: "PBXFrameworksBuildPhase", buildActionMask: 2147483647, files: [], runOnlyForDeploymentPostprocessing: 0 };
    add(objects, "PBXFrameworksBuildPhase", phaseID, "Frameworks", frameworksPhase);
    buildPhases.push({ value: phaseID, comment: "Frameworks" });
  }
  (frameworksPhase.files as Reference[]).push({ value: buildFileID, comment: buildFileComment });

  return {
    status: "linked",
    targetName: linkedTargetName,
    reusedReference: existingReference !== undefined,
    pbxproj: xcodeProject.writeSync(),
  };
}

/**
 * Links the SDK product into an app target of the `.xcodeproj` at `xcodeprojPath`.
 *
 * The new file is written next to the original, checked with `lint` and parsed back, and only then
 * moved over the original, so a failure leaves the project untouched.
 */
export function addPackage(
  xcodeprojPath: string,
  source: PackageSource,
  targetName?: string,
  lint: (pbxprojPath: string) => void = plutilLint,
): AddPackageResult {
  const pbxprojPath = join(xcodeprojPath, "project.pbxproj");
  if (!xcodeprojPath.endsWith(".xcodeproj") || !existsSync(pbxprojPath)) {
    return { status: "notFound" };
  }
  const specFile = generatorSpec(xcodeprojPath);
  if (specFile !== undefined) {
    return { status: "generated", specFile };
  }

  const plan = planPackageLink(pbxprojPath, source, targetName);
  if (plan.status !== "linked") {
    return plan;
  }

  const candidatePath = `${pbxprojPath}.${process.pid}.tmp`;
  writeFileSync(candidatePath, plan.pbxproj);
  try {
    lint(candidatePath);
    if (planPackageLink(candidatePath, source, plan.targetName).status !== "alreadyLinked") {
      throw new Error("The rewritten project does not link the package.");
    }
  } catch (error) {
    rmSync(candidatePath, { force: true });
    return { status: "invalid", reason: error instanceof Error ? error.message : String(error) };
  }
  renameSync(candidatePath, pbxprojPath);
  return { status: "linked", targetName: plan.targetName, reusedReference: plan.reusedReference };
}

function plutilLint(pbxprojPath: string): void {
  execFileSync("plutil", ["-lint", pbxprojPath], { stdio: "pipe" });
}

function records(section: Section | undefined): [string, Record<string, unknown>][] {
  return Object.entries(section ?? {}).filter(
    (entry): entry is [string, Record<string, unknown>] => !entry[0].endsWith("_comment") && typeof entry[1] === "object",
  );
}

function record(section: Section | undefined, id: string): Record<string, unknown> | undefined {
  const value = section?.[id];
  return typeof value === "object" ? value : undefined;
}

function section(objects: Record<string, Section | undefined>, name: string): Section {
  return (objects[name] ??= {});
}

function add(objects: Record<string, Section | undefined>, sectionName: string, id: string, comment: string, value: Record<string, unknown>): void {
  const target = section(objects, sectionName);
  target[id] = value;
  target[`${id}_comment`] = comment;
}

// The writer prints values verbatim, so anything beyond a bare word must arrive quoted and escaped.
function quote(value: string): string {
  return /^[A-Za-z0-9_./]+$/.test(value) ? value : `"${value.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;
}

function unquote(value: unknown): string {
  return typeof value === "string" ? value.replace(/^"(.*)"$/, "$1") : "";
}

function normalizedURL(url: string): string {
  return url.toLowerCase().replace(/\/+$/, "").replace(/\.git$/, "");
}

function repositoryName(url: string): string {
  return normalizedURL(url).split("/").pop() ?? url;
}
