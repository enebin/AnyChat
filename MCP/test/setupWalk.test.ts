import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { SetupWalk } from "./support/setupWalk.js";

const fixtureApps = new URL("../../test/fixtures/apps/", import.meta.url);

const setupOrder = [
  "Add the AnyChatUI package",
  "Add an in-memory backend",
  "Register the backend at the app root",
  "Add the chat screen",
  "Add a chat entry point",
];

function assertKeepsEveryLine(name: string, app: string, files: string[]) {
  for (const file of files) {
    const before = readFileSync(new URL(`${name}/${file}`, fixtureApps), "utf8").split("\n").filter((line) => line.trim());
    const after = readFileSync(join(app, file), "utf8").split("\n");
    const missing = before.filter((line) => !after.includes(line));
    assert.deepEqual(missing, [], `${file} lost lines`);
  }
}

test("an app with a TabView reaches the last step with a chat tab and keeps its code", () => {
  // Given
  const name = "tabs";

  // When
  const { app, nextSteps, steps } = SetupWalk.follow(name);

  // Then
  assert.deepEqual(nextSteps, setupOrder);
  assert.ok(steps.every((step) => step.status === "done"));
  assert.match(readFileSync(join(app, "App/RootView.swift"), "utf8"), /Tab\("Chat"[^]*ChatScreen\(\)/);
  assertKeepsEveryLine(name, app, ["App/ShopApp.swift", "App/RootView.swift"]);
});

test("an app with a NavigationStack reaches the last step with a chat sheet and keeps its code", () => {
  // Given
  const name = "navigation";

  // When
  const { app, nextSteps, steps } = SetupWalk.follow(name);

  // Then
  assert.deepEqual(nextSteps, setupOrder);
  assert.ok(steps.every((step) => step.status === "done"));
  assert.match(readFileSync(join(app, "App/NotesView.swift"), "utf8"), /\.sheet\(isPresented: \$showsChat\) \{\s*ChatScreen\(\)/);
  assertKeepsEveryLine(name, app, ["App/NotesApp.swift", "App/NotesView.swift"]);
});
