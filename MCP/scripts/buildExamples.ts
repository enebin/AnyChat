import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const examplesDirectory = join(repositoryRoot, "MCP", "catalog", "examples");
const target = "PlacementExamples";

const packageRoot = mkdtempSync(join(tmpdir(), "anychat-examples-"));
try {
  const sources = join(packageRoot, "Sources", target);
  mkdirSync(sources, { recursive: true });
  const examples = readdirSync(examplesDirectory).filter((name) => name.endsWith(".swift"));
  for (const example of examples) {
    cpSync(join(examplesDirectory, example), join(sources, example));
  }
  writeFileSync(join(packageRoot, "Package.swift"), manifest());

  const build = spawnSync(
    "xcodebuild",
    ["build", "-scheme", target, "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", join(packageRoot, "DerivedData"), "-quiet"],
    { cwd: packageRoot, encoding: "utf8" },
  );
  const output = `${build.stdout}${build.stderr}`;
  const warnings = output.split("\n").filter((line) => line.includes(": warning: "));

  if (build.status !== 0) {
    console.error(output);
    console.error("The placement examples in MCP/catalog/examples do not build against the SDK.");
    process.exitCode = 1;
  } else if (warnings.length > 0) {
    console.error(warnings.join("\n"));
    console.error("The placement examples in MCP/catalog/examples build with warnings.");
    process.exitCode = 1;
  } else {
    console.log(`${examples.length} placement examples build against the SDK with no warnings.`);
  }
} finally {
  rmSync(packageRoot, { recursive: true, force: true });
}

function manifest(): string {
  // A path dependency's identity is its directory name, which differs between checkouts and worktrees.
  const sdkPackage = basename(repositoryRoot);
  return `// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "${target}",
    platforms: [.iOS(.v18)],
    products: [.library(name: "${target}", targets: ["${target}"])],
    dependencies: [.package(path: ${JSON.stringify(repositoryRoot)})],
    targets: [
        .target(name: "${target}", dependencies: [.product(name: "AnyChatUI", package: ${JSON.stringify(sdkPackage)})])
    ],
    swiftLanguageModes: [.v6]
)
`;
}
