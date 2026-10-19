import { readFileSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { setupSteps, type SetupStep } from "../../src/guide.js";
import { addPackage } from "../../src/packageLink.js";
import { inspectProject } from "../../src/project.js";
import { Fixture } from "./fixtures.js";

const repositoryRoot = fileURLToPath(new URL("../../../../", import.meta.url));

/** How the agent fits the backend and the entry point into one fixture app. */
interface AppEdits {
  appFile: string;
  appDeclaration: string;
  rootView: string;
  addEntryPoint(app: string, instructions: string): void;
}

const edits: Record<"tabs" | "navigation", AppEdits> = {
  tabs: {
    appFile: "App/ShopApp.swift",
    appDeclaration: "struct ShopApp: App {",
    rootView: "RootView()",
    addEntryPoint(app, instructions) {
      const [tab] = swiftBlocks(instructions);
      insertAfter(join(app, "App/RootView.swift"), "        TabView {", indent(tab!, 12));
    },
  },
  navigation: {
    appFile: "App/NotesApp.swift",
    appDeclaration: "struct NotesApp: App {",
    rootView: "NotesView()",
    addEntryPoint(app, instructions) {
      const sheet = swiftBlocks(instructions)[2]!;
      const [property, modifiers] = sheet.split("\n\n// On the view inside the NavigationStack:\n");
      const file = join(app, "App/NotesView.swift");
      insertAfter(file, "struct NotesView: View {", indent(property!, 4));
      insertAfter(file, '            .navigationTitle("Notes")', indent(modifiers!, 12));
    },
  },
};

export const SetupWalk = {
  /**
   * Copies a fixture app and follows get_started from the first step, doing each step the way its instructions say.
   * Returns the app's directory and the step that was next after each action.
   */
  follow(name: "tabs" | "navigation"): { app: string; nextSteps: string[]; steps: SetupStep[] } {
    const app = Fixture.existingApp(name);
    const project = join(app, "App.xcodeproj");
    const appEdits = edits[name];
    const nextSteps: string[] = [];

    for (let attempt = 0; attempt < 10; attempt += 1) {
      const next = currentSteps(app).find((step) => step.status !== "done");
      if (!next) break;
      nextSteps.push(next.title);
      switch (next.title) {
        case "Add the AnyChatUI package":
          addPackage(project, { kind: "local", relativePath: relative(app, repositoryRoot) }, undefined);
          break;
        case "Add an in-memory backend":
          writeFileSync(join(app, "App/InMemoryChatBackend.swift"), `${swiftBlocks(next.instructions)[0]}\n`);
          break;
        case "Register the backend at the app root": {
          const file = join(app, appEdits.appFile);
          insertAfter(file, "import SwiftUI", "import AnyChatUI");
          insertAfter(file, appEdits.appDeclaration, "    @State private var backend = InMemoryChatBackend()\n");
          insertAfter(file, `            ${appEdits.rootView}`, "                .chatBackend(backend)");
          break;
        }
        case "Add the chat screen":
          writeFileSync(join(app, "App/ChatScreen.swift"), `${swiftBlocks(next.instructions)[0]}\n`);
          break;
        case "Add a chat entry point":
          appEdits.addEntryPoint(app, next.instructions);
          break;
        default:
          throw new Error(`The walk does not know how to do "${next.title}".`);
      }
    }
    return { app, nextSteps, steps: currentSteps(app) };
  },
};

function currentSteps(app: string): SetupStep[] {
  const result = inspectProject(app);
  if (!result.found) throw new Error(`No project in ${app}`);
  return setupSteps(result.inspection, Fixture.sdkVersion);
}

function swiftBlocks(instructions: string): string[] {
  return [...instructions.matchAll(/```swift\n([\s\S]*?)\n```/g)].map((match) => match[1]!);
}

function insertAfter(file: string, anchorLine: string, text: string): void {
  const lines = readFileSync(file, "utf8").split("\n");
  const index = lines.indexOf(anchorLine);
  if (index === -1) throw new Error(`"${anchorLine}" is not a line of ${file}`);
  lines.splice(index + 1, 0, text);
  writeFileSync(file, lines.join("\n"));
}

function indent(source: string, spaces: number): string {
  return source.split("\n").map((line) => (line ? " ".repeat(spaces) + line : line)).join("\n");
}
