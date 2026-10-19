import assert from "node:assert/strict";
import { test } from "node:test";
import { renderComponent } from "../src/catalog.js";
import { renderDemo, renderUnknownDemo, type Demo } from "../src/demos.js";
import { Fixture } from "./support/fixtures.js";

const agent: Demo = {
  name: "Agent",
  description: "An agent transcript.",
  components: ["ListView"],
  files: ["Showcase/Agent/AgentDemo.swift"],
  standIns: ["SampleChatBackend", "SampleData"],
  registersBackend: true,
};

const sources: Record<string, string> = {
  "Showcase/Agent/AgentDemo.swift": "struct AgentDemo: View {\n    var body: some View { ListView() }\n}\n",
};

test("a demo is shown as a reference with its files and its stand-ins named", () => {
  // Given
  const readFile = (path: string) => sources[path]!;

  // When
  const text = renderDemo(agent, readFile);

  // Then
  assert.ok(text.startsWith("# `Agent` demo\n\nAn agent transcript."));
  assert.match(text, /a reference to read, not code to paste/);
  assert.match(text, /`SampleChatBackend`, `SampleData` come from the Showcase app's sample code/);
  assert.match(text, /registers its own sample backend .* only to stay separate from the other demos/);
  assert.ok(text.includes("## `Showcase/Agent/AgentDemo.swift`\n\n```swift\nstruct AgentDemo: View {"));
});

test("a demo that registers no backend has no note about it", () => {
  // Given
  const readFile = (path: string) => sources[path]!;

  // When
  const text = renderDemo({ ...agent, registersBackend: false }, readFile);

  // Then
  assert.doesNotMatch(text, /registers its own sample backend/);
});

test("an unknown demo name lists the demos with their descriptions", () => {
  // Given
  const index = { demos: [agent] };

  // When
  const text = renderUnknownDemo(index, "Agents");

  // Then
  assert.equal(text, "There is no demo named `Agents`. The demos are:\n\n- `Agent`: An agent transcript.");
});

test("a component description ends with the demos that use it", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const description = renderComponent(catalog, catalog.components[0]!, "struct Placement {}", [agent]);

  // Then
  assert.match(description, /## Demos\n\n.*Call `show_demo` with a name for its source\.\n\n- `Agent`: An agent transcript\.$/);
});
