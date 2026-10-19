import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { addPackage, planPackageLink, type PackageSource } from "../src/packageLink.js";
import { Fixture } from "./support/fixtures.js";

const Constant = {
  remote: { kind: "remote", url: "https://github.com/example/anychat", minimumVersion: "1.2.3" } satisfies PackageSource,
  local: { kind: "local", relativePath: "../anychat" } satisfies PackageSource,
  passingLint: () => {},
};

function pbxproj(xcodeprojPath: string): string {
  return readFileSync(join(xcodeprojPath, "project.pbxproj"), "utf8");
}

/** Whether every line of `original` is still in `edited`, in order: the edit only added lines. */
function onlyAddsLines(original: string, edited: string): boolean {
  const editedLines = edited.split("\n");
  let index = 0;
  for (const line of original.split("\n")) {
    index = editedLines.indexOf(line, index);
    if (index === -1) {
      return false;
    }
    index += 1;
  }
  return true;
}

for (const layout of ["synchronized", "listed"] as const) {
  test(`a ${layout} project gets the package linked into its app target by adding lines only`, () => {
    // Given
    const project = Fixture.xcodeProject(layout);
    const original = pbxproj(project);

    // When
    const result = addPackage(project, Constant.remote, undefined, Constant.passingLint);

    // Then
    assert.deepEqual(result, { status: "linked", targetName: "App", reusedReference: false });
    const edited = pbxproj(project);
    assert.ok(onlyAddsLines(original, edited));
    assert.match(edited, /isa = XCRemoteSwiftPackageReference;\s+repositoryURL = "https:\/\/github\.com\/example\/anychat";\s+requirement = \{\s+kind = upToNextMajorVersion;\s+minimumVersion = 1\.2\.3;/);
    assert.match(edited, /packageReferences = \(\s+\w{24} \/\* XCRemoteSwiftPackageReference "anychat" \*\/,/);
    assert.match(edited, /isa = XCSwiftPackageProductDependency;\s+package = \w{24} \/\* XCRemoteSwiftPackageReference "anychat" \*\/;\s+productName = AnyChatUI;/);
    assert.match(edited, /\/\* AnyChatUI in Frameworks \*\/ = \{isa = PBXBuildFile; productRef = \w{24} \/\* AnyChatUI \*\/; \};/);
    assert.equal(planPackageLink(join(project, "project.pbxproj"), Constant.remote).status, "alreadyLinked");
  });
}

test("the only existing lines the edit changes are integers with leading zeros", () => {
  // Given
  const project = Fixture.xcodeProject("listed");
  const pbxprojPath = join(project, "project.pbxproj");
  writeFileSync(pbxprojPath, pbxproj(project).replace(/LastUpgradeCheck = \d+;/, "LastUpgradeCheck = 0800;"));
  const original = pbxproj(project);

  // When
  addPackage(project, Constant.remote, undefined, Constant.passingLint);

  // Then
  const edited = pbxproj(project);
  assert.match(edited, /LastUpgradeCheck = 800;/);
  assert.ok(onlyAddsLines(original.replace("LastUpgradeCheck = 0800;", "LastUpgradeCheck = 800;"), edited));
});

test("a target without a Frameworks phase gets one", () => {
  // Given
  const project = Fixture.xcodeProject("listed");
  assert.doesNotMatch(pbxproj(project), /isa = PBXFrameworksBuildPhase;/);

  // When
  addPackage(project, Constant.remote, undefined, Constant.passingLint);

  // Then
  assert.match(pbxproj(project), /isa = PBXFrameworksBuildPhase;\s+buildActionMask = 2147483647;\s+files = \(\s+\w{24} \/\* AnyChatUI in Frameworks \*\/,/);
});

test("a local checkout is referenced by its relative path", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");

  // When
  addPackage(project, Constant.local, undefined, Constant.passingLint);

  // Then
  assert.match(pbxproj(project), /isa = XCLocalSwiftPackageReference;\s+relativePath = \.\.\/anychat;/);
});

test("a second call changes nothing", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");
  addPackage(project, Constant.remote, undefined, Constant.passingLint);
  const linked = pbxproj(project);

  // When
  const result = addPackage(project, Constant.remote, undefined, Constant.passingLint);

  // Then
  assert.deepEqual(result, { status: "alreadyLinked", targetName: "App" });
  assert.equal(pbxproj(project), linked);
});

test("an existing reference to the package is reused for another target", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");
  addPackage(project, Constant.remote, "AppTests", Constant.passingLint);

  // When
  const result = addPackage(project, { ...Constant.remote, url: `${Constant.remote.url}.git/` }, "App", Constant.passingLint);

  // Then
  assert.deepEqual(result, { status: "linked", targetName: "App", reusedReference: true });
  assert.equal(pbxproj(project).match(/isa = XCRemoteSwiftPackageReference;/g)?.length, 1);
});

test("several app targets and no target name return the app targets to choose from", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");
  const pbxprojPath = join(project, "project.pbxproj");
  writeFileSync(pbxprojPath, pbxproj(project).replace("com.apple.product-type.bundle.unit-test", "com.apple.product-type.application"));
  const original = pbxproj(project);

  // When
  const result = addPackage(project, Constant.remote, undefined, Constant.passingLint);

  // Then
  assert.deepEqual(result, { status: "chooseTarget", candidates: ["App", "AppTests"] });
  assert.equal(pbxproj(project), original);
});

test("an unknown target name returns every target to choose from", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");

  // When
  const result = addPackage(project, Constant.remote, "Widget", Constant.passingLint);

  // Then
  assert.deepEqual(result, { status: "chooseTarget", candidates: ["App", "AppTests"] });
});

test("a generated project is left alone", () => {
  // Given
  const projects = [
    Fixture.xcodeProject("listed", { "project.yml": "name: App" }),
    Fixture.xcodeProject("listed", { "Project.swift": "" }),
  ];

  // When
  const results = projects.map((project) => {
    const original = pbxproj(project);
    return { original, project, result: addPackage(project, Constant.remote, undefined, Constant.passingLint) };
  });

  // Then
  assert.deepEqual(results.map(({ result }) => result), [
    { status: "generated", specFile: "project.yml" },
    { status: "generated", specFile: "Project.swift" },
  ]);
  for (const { original, project } of results) {
    assert.equal(pbxproj(project), original);
  }
});

test("a failed check leaves the project untouched and no temporary file behind", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");
  const original = pbxproj(project);

  // When
  const result = addPackage(project, Constant.remote, undefined, () => {
    throw new Error("lint failed");
  });

  // Then
  assert.deepEqual(result, { status: "invalid", reason: "lint failed" });
  assert.equal(pbxproj(project), original);
  assert.deepEqual(readdirSync(project), ["project.pbxproj"]);
});

test("the default check accepts what the tool writes", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");

  // When
  const result = addPackage(project, Constant.remote);

  // Then
  assert.equal(result.status, "linked");
});

test("a path that is not an .xcodeproj with a project file finds nothing", () => {
  // Given
  const project = Fixture.xcodeProject("synchronized");

  // When
  const results = [addPackage(dirname(project), Constant.remote), addPackage(join(dirname(project), "Missing.xcodeproj"), Constant.remote)];

  // Then
  assert.deepEqual(results, [{ status: "notFound" }, { status: "notFound" }]);
  assert.ok(existsSync(join(project, "project.pbxproj")));
});
