import { existsSync, readFileSync } from "node:fs";

export interface Demo {
  name: string;
  description: string;
  /** The component views named in the demo's own files. */
  components: string[];
  /** Paths relative to the demos directory, such as `Showcase/Agent/AgentDemo.swift`. */
  files: string[];
  /** Types from `Shared/` that the demo uses. They are not shipped. */
  standIns: string[];
  registersBackend: boolean;
}

export interface DemoIndex {
  demos: Demo[];
}

const demosDirectory = new URL("../../demos/", import.meta.url);

/** The demos copied into the package by `scripts/packDemos.ts`, or none when the server runs from a checkout that has not run it. */
export function readDemoIndex(): DemoIndex {
  const index = new URL("index.json", demosDirectory);
  return existsSync(index) ? JSON.parse(readFileSync(index, "utf8")) : { demos: [] };
}

export function readDemoFile(path: string): string {
  return readFileSync(new URL(path, demosDirectory), "utf8");
}

export function renderDemo(demo: Demo, readFile: (path: string) => string): string {
  const standIns = demo.standIns.map((name) => `\`${name}\``).join(", ");
  const notes = [
    "This demo is a reference to read, not code to paste. It is built from public API only and compiles against the SDK version this server guides.",
    ...(demo.standIns.length > 0
      ? [`${standIns} come from the Showcase app's sample code and are not shown. They stand in for the app's own backend and values; replace them with the app's own.`]
      : []),
    ...(demo.registersBackend
      ? ["The demo registers its own sample backend with `.chatBackend(_:)` only to stay separate from the other demos. The app keeps its single backend registered at its root."]
      : []),
  ];
  const sources = demo.files.map((path) => `## \`${path}\`\n\n${swift(readFile(path))}`);
  return [`# \`${demo.name}\` demo`, demo.description, notes.join(" "), ...sources].join("\n\n");
}

export function renderUnknownDemo(index: DemoIndex, name: string): string {
  return [`There is no demo named \`${name}\`. The demos are:`, renderDemoList(index.demos)].join("\n\n");
}

export function renderDemoList(demos: Demo[]): string {
  return demos.map((demo) => `- \`${demo.name}\`: ${demo.description}`).join("\n");
}

function swift(source: string): string {
  return `\`\`\`swift\n${source.trimEnd()}\n\`\`\``;
}
