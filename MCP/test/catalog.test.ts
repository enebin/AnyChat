import assert from "node:assert/strict";
import { test } from "node:test";
import {
  readCatalog,
  readPlacementExample,
  renderComponent,
  renderComponentList,
  renderUnknownComponent,
} from "../src/catalog.js";
import { Fixture } from "./support/fixtures.js";

const example = "struct ChatHome: View {}\n";

function headings(markdown: string): string[] {
  return markdown.split("\n").filter((line) => line.startsWith("## ")).map((line) => line.slice(3));
}

test("the component list names each component with the first sentence of its documentation", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const list = renderComponentList(catalog);

  // Then
  assert.match(list, /^- `ListView`: A list of channels\.$/m);
  assert.doesNotMatch(list, /It loads from the backend/);
  assert.match(list, /describe_component/);
});

test("a component description starts with its documentation and follows the catalog's order", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const description = renderComponent(catalog, catalog.components[0]!, example, []);

  // Then
  assert.ok(description.startsWith("# `ListView`\n\nA list of channels. It loads from the backend.\n\nMore detail."));
  assert.deepEqual(headings(description), [
    "Initializers",
    "Slots",
    "Callbacks",
    "Theme",
    "Options",
    "Context values",
    "Domain types",
    "Backend boundary",
    "Placement example",
  ]);
  assert.ok(description.endsWith(`\`\`\`swift\n${example.trimEnd()}\n\`\`\``));
});

test("a type is shown as a Swift interface with its conformances, every member, and its doc comment", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const description = renderComponent(catalog, catalog.components[0]!, example, []);

  // Then
  const channel = [
    "/// Documents Channel.",
    "struct Channel: Hashable, Sendable {",
    "    enum Kind {",
    "        case direct",
    "        case group",
    "    }",
    "",
    "    /// The name.",
    "    ///",
    "    /// - Since: 1.0.0",
    "    var name: String",
    "}",
  ].join("\n");
  assert.ok(description.includes(channel));
});

test("the backend boundary is named without its members and points to backend registration", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const description = renderComponent(catalog, catalog.components[0]!, example, []);

  // Then
  assert.match(description, /Not described here: `ListRepository`\./);
  assert.match(description, /`\.chatBackend\(_:\)`/);
});

test("parts a component does not have are left out", () => {
  // Given
  const catalog = Fixture.catalog({ theme: undefined, options: undefined, contextValues: [], backendBoundary: [] });

  // When
  const description = renderComponent(catalog, catalog.components[0]!, undefined, []);

  // Then
  assert.deepEqual(headings(description), ["Initializers", "Slots", "Callbacks", "Domain types"]);
});

test("an unknown component name returns the known names", () => {
  // Given
  const catalog = Fixture.catalog();

  // When
  const message = renderUnknownComponent(catalog, "ChannelScreen");

  // Then
  assert.equal(message, "There is no component named `ChannelScreen`. The components are `ListView`.");
});

test("every component in the shipped catalog has a placement example", () => {
  // Given
  const catalog = readCatalog();

  // When
  const missing = catalog.components.filter((component) => readPlacementExample(component.name) === undefined);

  // Then
  assert.ok(catalog.components.length > 0);
  assert.deepEqual(missing.map((component) => component.name), []);
});
