import { cpSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { readCatalog } from "../src/catalog.js";
import { buildDemoIndex, type SourceFile } from "./demoIndex.js";

const examplesRoot = fileURLToPath(new URL("../../../Examples/QuickStart/", import.meta.url));
const demosDirectory = fileURLToPath(new URL("../../demos/", import.meta.url));

const index = buildDemoIndex(
  readdirSync(join(examplesRoot, "Showcase"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .flatMap((entry) => readSources(`Showcase/${entry.name}`)),
  readSources("Shared"),
  readCatalog().components.map((component) => component.name),
);

rmSync(demosDirectory, { recursive: true, force: true });
for (const path of index.demos.flatMap((demo) => demo.files)) {
  mkdirSync(dirname(join(demosDirectory, path)), { recursive: true });
  cpSync(join(examplesRoot, path), join(demosDirectory, path));
}
writeFileSync(join(demosDirectory, "index.json"), `${JSON.stringify(index, null, 2)}\n`);
console.log(`Packed ${index.demos.length} demos into MCP/demos.`);

function readSources(folder: string): SourceFile[] {
  return readdirSync(join(examplesRoot, folder))
    .filter((name) => name.endsWith(".swift"))
    .sort()
    .map((name) => ({ path: `${folder}/${name}`, text: readFileSync(join(examplesRoot, folder, name), "utf8") }));
}
