import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";

export const productName = "AnyChatUI";

export type ProjectKind = "xcodeProject" | "swiftPackage";

export interface ProjectInspection {
  kind: ProjectKind;
  /** The `.xcodeproj` directory or the `Package.swift` file. */
  projectPath: string;
  /** The lowest iOS deployment target found, such as `"17.0"`, or `undefined` when none is declared. */
  iosDeploymentTarget: string | undefined;
  dependsOnSDK: boolean;
  /** The spec file a project generator rebuilds the `.xcodeproj` from, such as `project.yml`. */
  generatorSpec: string | undefined;
  /** Whether a new `.swift` file on disk is compiled without being listed in the project file. */
  compilesNewFiles: boolean;
  /** Whether a type adopting `ChatBackend` is declared in a file the project compiles. */
  implementsBackend: boolean;
  registersBackend: boolean;
  /** Whether a file the project compiles uses `ChannelListView`, in the screen setup adds or in one of the app's own. */
  placesChannelList: boolean;
  /** A type declared in the app whose body uses `ChannelListView`, so the entry point step can name the screen to open. */
  channelListScreen: string | undefined;
  /** Whether a view that uses `ChannelListView` is opened from somewhere other than its own declaration, or is the app itself. */
  opensChannelList: boolean;
  hasUITestTarget: boolean;
  /** Whether a file the project compiles launches the app in a UI test and taps the composer's Send button. */
  hasChatUITest: boolean;
}

export type InspectionResult =
  | { found: true; inspection: ProjectInspection }
  | { found: false; candidates: string[] };

const skippedDirectories = new Set([".build", ".git", ".swiftpm", "Carthage", "DerivedData", "Pods", "build", "node_modules"]);
const candidateSearchDepth = 2;

export function inspectProject(path: string): InspectionResult {
  const candidates = path.endsWith(".xcodeproj") || basename(path) === "Package.swift"
    ? [path].filter((candidate) => existsSync(candidate))
    : findCandidates(path, candidateSearchDepth);
  if (candidates.length !== 1) {
    return { found: false, candidates };
  }

  const projectPath = candidates[0]!;
  const sources = readSwiftSources(dirname(projectPath));
  const kind: ProjectKind = projectPath.endsWith(".xcodeproj") ? "xcodeProject" : "swiftPackage";
  const manifest = readFileSync(kind === "xcodeProject" ? join(projectPath, "project.pbxproj") : projectPath, "utf8");
  // Projects from before Xcode 16 list every file in project.pbxproj, so a file that is only on disk is not compiled.
  const compilesNewFiles = kind === "swiftPackage" || manifest.includes("PBXFileSystemSynchronizedRootGroup");
  const isCompiled = (source: SwiftSource) => compilesNewFiles || manifest.includes(source.name);
  const compiledCode = sources.filter(isCompiled).map((source) => withoutPreviews(code(source.text)));
  const hosts = channelListHosts(compiledCode);

  return {
    found: true,
    inspection: {
      kind,
      projectPath,
      iosDeploymentTarget: kind === "xcodeProject" ? pbxprojDeploymentTarget(manifest) : packageDeploymentTarget(manifest),
      dependsOnSDK: kind === "xcodeProject"
        ? new RegExp(`productName = "?${productName}"?;`).test(manifest)
        : manifest.includes(`"${productName}"`),
      generatorSpec: kind === "xcodeProject" ? generatorSpec(projectPath) : undefined,
      compilesNewFiles,
      implementsBackend: sources.some((source) =>
        isCompiled(source) && /\b(?:class|struct|actor|enum|extension)\s+[\w.]+(?:<[^>]*>)?\s*:\s*(?:[\w.<>]+\s*,\s*)*ChatBackend\b/.test(source.text)
      ),
      registersBackend: sources.some((source) => source.text.includes(".chatBackend(")),
      placesChannelList: compiledCode.some((text) => channelListUse.test(text)),
      channelListScreen: channelListScreen(hosts, compiledCode),
      opensChannelList: opensChannelList(hosts, compiledCode),
      hasUITestTarget: manifest.includes("com.apple.product-type.bundle.ui-testing"),
      hasChatUITest: sources.some((source) =>
        isCompiled(source) && source.text.includes("XCUIApplication") && source.text.includes('buttons["Send"]')
      ),
    },
  };
}

const channelListUse = /\bChannelListView\(/;
const appConformance = /:\s*(?:[\w.]+\s*,\s*)*(?:SwiftUI\.)?App\b/;

/** The innermost type declaration around each use of `ChannelListView`. */
function channelListHosts(compiledCode: string[]): TypeDeclaration[] {
  return compiledCode.flatMap((text) => {
    const types = typeDeclarations(text);
    return [...text.matchAll(new RegExp(channelListUse.source, "g"))].flatMap((use) => {
      const enclosing = types.filter((type) => type.start < use.index && use.index < type.end);
      return enclosing.length > 0 ? [enclosing[enclosing.length - 1]!] : [];
    });
  });
}

/** The first host that the app declares as a type; an `extension View` helper is a host but not a screen to open. */
function channelListScreen(hosts: TypeDeclaration[], compiledCode: string[]): string | undefined {
  const declared = new Set(
    compiledCode.flatMap((text) => typeDeclarations(text).filter((type) => !type.header.startsWith("extension")).map((type) => type.name)),
  );
  return hosts.find((host) => declared.has(host.name))?.name;
}

/**
 * Whether a host is the app itself or appears as `Name(` outside its own declarations.
 * The declarations are skipped because a project that lists each file pastes the chat screen into an existing file,
 * which may hold the entry point too.
 */
function opensChannelList(hosts: TypeDeclaration[], compiledCode: string[]): boolean {
  return hosts.some((host) =>
    appConformance.test(host.header) ||
    compiledCode.some((text) => new RegExp(`\\b${host.name}\\(`).test(withoutDeclarationsOf(text, host.name)))
  );
}

interface TypeDeclaration {
  name: string;
  /** From the keyword to the opening brace, such as `struct ChatScreen: View `. */
  header: string;
  start: number;
  end: number;
}

// Words that follow `class` in a member declaration such as `class func`, not a type name.
const memberKeywords = new Set(["func", "var", "let", "subscript", "init", "override", "final", "static"]);

/** Type declarations and extensions in source order, nested ones after the type that holds them. */
function typeDeclarations(text: string): TypeDeclaration[] {
  return [...text.matchAll(/\b(?:struct|class|enum|actor|extension)\s+(\w+)[^{;]*/g)]
    .filter((match) => !memberKeywords.has(match[1]!))
    .map((match) => ({ name: match[1]!, header: match[0], start: match.index, end: blockEnd(text, match.index) }));
}

function withoutDeclarationsOf(text: string, name: string): string {
  return typeDeclarations(text)
    .filter((type) => type.name === name)
    .reverse()
    .reduce((rest, type) => rest.slice(0, type.start) + rest.slice(type.end), text);
}

function withoutPreviews(text: string): string {
  let rest = text;
  let start: number;
  while ((start = rest.search(/#Preview\b/)) !== -1) {
    rest = rest.slice(0, start) + rest.slice(blockEnd(rest, start));
  }
  return rest;
}

/**
 * The source without comments and with every string literal emptied, so `//` in a URL and braces in text
 * are not read as code.
 */
function code(text: string): string {
  let result = "";
  let index = 0;
  while (index < text.length) {
    if (text.startsWith("//", index)) {
      const end = text.indexOf("\n", index);
      index = end === -1 ? text.length : end;
    } else if (text.startsWith("/*", index)) {
      index = blockCommentEnd(text, index);
    } else if (text.startsWith('"""', index)) {
      const end = text.indexOf('"""', index + 3);
      index = end === -1 ? text.length : end + 3;
      result += '""';
    } else if (/^#+"/.test(text.slice(index, index + 8))) {
      const hashes = text.slice(index).match(/^#+/)![0];
      const end = text.indexOf(`"${hashes}`, index + hashes.length + 1);
      index = end === -1 ? text.length : end + hashes.length + 1;
      result += '""';
    } else if (text[index] === '"') {
      index += 1;
      while (index < text.length && text[index] !== '"' && text[index] !== "\n") {
        index += text[index] === "\\" ? 2 : 1;
      }
      index += 1;
      result += '""';
    } else {
      result += text[index];
      index += 1;
    }
  }
  return result;
}

/** Swift block comments nest. */
function blockCommentEnd(text: string, from: number): number {
  let depth = 0;
  for (let index = from; index < text.length - 1; index += 1) {
    if (text.startsWith("/*", index)) {
      depth += 1;
      index += 1;
    } else if (text.startsWith("*/", index)) {
      depth -= 1;
      index += 1;
      if (depth === 0) return index + 1;
    }
  }
  return text.length;
}

/** The index just past the brace block that follows `from`, or the end of the text when the braces never close. */
function blockEnd(text: string, from: number): number {
  const open = text.indexOf("{", from);
  if (open === -1) return text.length;
  let depth = 0;
  for (let index = open; index < text.length; index += 1) {
    if (text[index] === "{") depth += 1;
    if (text[index] === "}" && --depth === 0) return index + 1;
  }
  return text.length;
}

const generatorSpecs = ["project.yml", "Project.swift"];

/** The XcodeGen or Tuist spec next to the `.xcodeproj`, whose regeneration overwrites `project.pbxproj`. */
export function generatorSpec(xcodeprojPath: string): string | undefined {
  return generatorSpecs.find((name) => existsSync(join(dirname(xcodeprojPath), name)));
}

function findCandidates(directory: string, depth: number): string[] {
  if (!existsSync(directory) || !statSync(directory).isDirectory()) {
    return [];
  }
  const candidates: string[] = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory() && entry.name.endsWith(".xcodeproj")) {
      candidates.push(path);
    } else if (entry.isFile() && entry.name === "Package.swift") {
      candidates.push(path);
    } else if (entry.isDirectory() && depth > 0 && !isSkipped(entry.name)) {
      candidates.push(...findCandidates(path, depth - 1));
    }
  }
  return candidates.sort();
}

interface SwiftSource {
  name: string;
  text: string;
}

function readSwiftSources(directory: string): SwiftSource[] {
  const sources: SwiftSource[] = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory() && !isSkipped(entry.name)) {
      sources.push(...readSwiftSources(path));
    } else if (entry.isFile() && entry.name.endsWith(".swift") && entry.name !== "Package.swift") {
      sources.push({ name: entry.name, text: readFileSync(path, "utf8") });
    }
  }
  return sources;
}

function isSkipped(name: string): boolean {
  return skippedDirectories.has(name) || name.endsWith(".xcodeproj") || name.endsWith(".xcworkspace");
}

function pbxprojDeploymentTarget(pbxproj: string): string | undefined {
  const targets = [...pbxproj.matchAll(/IPHONEOS_DEPLOYMENT_TARGET = "?([\d.]+)"?;/g)].map((match) => match[1]!);
  return lowestVersion(targets);
}

function packageDeploymentTarget(manifest: string): string | undefined {
  const targets = [...manifest.matchAll(/\.iOS\(\s*(?:\.v(\d+)(?:_(\d+))?|"([\d.]+)")\s*\)/g)].map(
    ([, major, minor, literal]) => literal ?? `${major}.${minor ?? "0"}`,
  );
  return lowestVersion(targets);
}

function lowestVersion(versions: string[]): string | undefined {
  return versions.sort((a, b) => compareVersions(a, b))[0];
}

export function compareVersions(a: string, b: string): number {
  const left = a.split(".").map(Number);
  const right = b.split(".").map(Number);
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const difference = (left[index] ?? 0) - (right[index] ?? 0);
    if (difference !== 0) {
      return difference;
    }
  }
  return 0;
}
