import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { buildCatalog, catalogModules, type SymbolGraph } from "./catalog.js";

const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const catalogPath = join(repositoryRoot, "MCP", "catalog", "components.json");
const checkOnly = process.argv.includes("--check");

const derivedData = mkdtempSync(join(tmpdir(), "anychat-catalog-"));
try {
  // `swift build` cannot build an iOS-only package, and `docbuild` emits symbol graphs without overriding the package's compiler flags.
  execFileSync(
    "xcodebuild",
    ["docbuild", "-scheme", "AnyChat", "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", derivedData, "-quiet"],
    { cwd: repositoryRoot, stdio: "inherit" },
  );
  const catalog = `${JSON.stringify(buildCatalog(readSymbolGraphs(derivedData)), null, 2)}\n`;
  const displayPath = relative(process.cwd(), catalogPath);

  if (checkOnly) {
    if (!existsSync(catalogPath) || readFileSync(catalogPath, "utf8") !== catalog) {
      console.error(`${displayPath} does not match the SDK's public API. Run \`npm run catalog\` in MCP/ and commit the result.`);
      process.exitCode = 1;
    } else {
      console.log(`${displayPath} is up to date.`);
    }
  } else {
    mkdirSync(dirname(catalogPath), { recursive: true });
    writeFileSync(catalogPath, catalog);
    console.log(`Wrote ${displayPath}.`);
  }
} finally {
  rmSync(derivedData, { recursive: true, force: true });
}

function readSymbolGraphs(directory: string): SymbolGraph[] {
  // The generic destination builds every simulator architecture; their graphs are identical, so one is enough.
  const architecture = `${sep}arm64-apple-ios-simulator${sep}`;
  const modules = Object.values(catalogModules);
  return readdirSync(directory, { recursive: true, encoding: "utf8" })
    .filter((path) => path.endsWith(".symbols.json") && path.includes(architecture))
    .sort()
    .map((path) => JSON.parse(readFileSync(join(directory, path), "utf8")) as SymbolGraph)
    .filter((graph) => modules.includes(graph.module.name));
}
