import { firstSentence } from "../src/catalog.js";
import type { DemoIndex } from "../src/demos.js";

export interface SourceFile {
  /** Relative to `Examples/QuickStart`, such as `Showcase/Agent/AgentDemo.swift`. */
  path: string;
  text: string;
}

/** Builds the demo index from the Showcase and Shared sources, following the rules in docs/architecture/mcp.md "Demos". */
export function buildDemoIndex(showcase: SourceFile[], shared: SourceFile[], componentNames: string[]): DemoIndex {
  const folders = new Map<string, SourceFile[]>();
  for (const file of showcase) {
    const name = file.path.match(/^Showcase\/(\w+)\//)?.[1];
    if (name) {
      folders.set(name, [...(folders.get(name) ?? []), file]);
    }
  }
  const standIns = shared.flatMap((file) => topLevelTypes(file.text)).sort();

  return {
    demos: [...folders.keys()].sort().map((name) => {
      const files = folders.get(name)!;
      const text = files.map((file) => file.text).join("\n");
      const summary = description(text, `${name}Demo`);
      if (summary.length === 0) {
        throw new Error(`Showcase/${name}: the ${name}Demo view needs a /// comment; its first sentence is the demo's description.`);
      }
      return {
        name,
        description: summary,
        components: componentNames.filter((component) => mentions(text, component)),
        files: files.map((file) => file.path),
        standIns: standIns.filter((type) => mentions(text, type)),
        registersBackend: text.includes(".chatBackend("),
      };
    }),
  };
}

function description(text: string, view: string): string {
  const lines = text.split("\n");
  const declaration = lines.findIndex((line) => new RegExp(`^(?:@\\w+\\s+)*struct\\s+${view}\\b`).test(line));
  let index = declaration - 1;
  while (index >= 0 && lines[index]!.startsWith("@")) index -= 1;
  const comment: string[] = [];
  for (; index >= 0 && lines[index]!.startsWith("///"); index -= 1) {
    comment.unshift(lines[index]!.replace(/^\/\/\/ ?/, ""));
  }
  return firstSentence(comment.join("\n"));
}

function topLevelTypes(text: string): string[] {
  return [...text.matchAll(/^(?:(?:nonisolated|final|public)\s+)*(?:struct|class|enum|actor|protocol)\s+(\w+)/gm)].map((match) => match[1]!);
}

function mentions(text: string, name: string): boolean {
  return new RegExp(`\\b${name}\\b`).test(text);
}
