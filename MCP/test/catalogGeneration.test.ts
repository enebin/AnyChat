import assert from "node:assert/strict";
import { test } from "node:test";
import { buildCatalog } from "../scripts/catalog.js";
import type { Catalog, CatalogComponent } from "../src/catalog.js";
import { SymbolGraphs } from "./support/symbolGraphs.js";

const { ref, viewProtocol } = SymbolGraphs;

const id = {
  listView: "ui:ListView",
  listTheme: "ui:ListTheme",
  listOptions: "ui:ListOptions",
  rowContext: "ui:RowContext",
  channel: "core:Channel",
  message: "core:Message",
  messageKind: "core:Message.Kind",
  repository: "core:Repository",
  page: "core:Page",
  identified: "core:Identified",
};

function sdkGraphs() {
  const ui = SymbolGraphs.graph("AnyChatUI", [
    { id: id.listView, kind: "struct", path: ["ListView"], declaration: ["struct ListView"], doc: "A list.", conformsTo: [viewProtocol] },
    { id: "ui:ListView.init(options:)", kind: "init", path: ["ListView", "init(options:)"], memberOf: id.listView, line: 1,
      declaration: ["init(options: ", ref("ListOptions", id.listOptions), ")"], doc: "Creates a list." },
    { id: "ui:ListView.init(repository:)", kind: "init", path: ["ListView", "init(repository:)"], memberOf: id.listView, line: 2,
      declaration: ["init(repository: any ", ref("Repository", id.repository), ")"] },
    { id: "ui:ListView.row(_:)", kind: "method", path: ["ListView", "row(_:)"], memberOf: id.listView, line: 3,
      declaration: ["func row(_ content: (", ref("Channel", id.channel), ") -> some ", ref("View", viewProtocol), ") -> ListView"] },
    { id: "ui:ListView.onSelected(_:)", kind: "method", path: ["ListView", "onSelected(_:)"], memberOf: id.listView, line: 4,
      declaration: ["func onSelected(_ action: (", ref("Channel", id.channel), ", ", ref("RowContext", id.rowContext), ") -> Void) -> ListView"] },
    { id: "ui:ListView.title(_:)", kind: "method", path: ["ListView", "title(_:)"], memberOf: id.listView, line: 5,
      declaration: ["func title(_ text: String) -> ListView"] },
    { id: id.listTheme, kind: "struct", path: ["ListTheme"], declaration: ["struct ListTheme"] },
    { id: "ui:ListTheme.tint", kind: "property", path: ["ListTheme", "tint"], memberOf: id.listTheme, line: 1,
      declaration: ["var tint: Color"], doc: "The tint." },
    { id: "ui:ListTheme.light", kind: "type.property", path: ["ListTheme", "light"], memberOf: id.listTheme, line: 2,
      declaration: ["static let light: ListTheme"] },
    { id: id.listOptions, kind: "struct", path: ["ListOptions"], declaration: ["struct ListOptions"] },
    { id: "ui:ListOptions.isEnabled", kind: "property", path: ["ListOptions", "isEnabled"], memberOf: id.listOptions,
      declaration: ["var isEnabled: Bool"] },
    { id: id.rowContext, kind: "struct", path: ["RowContext"], declaration: ["struct RowContext"] },
    { id: "ui:RowContext.Position", kind: "enum", path: ["RowContext", "Position"], memberOf: id.rowContext,
      declaration: ["enum Position"] },
    { id: "ui:RowContext.Position.first", kind: "enum.case", path: ["RowContext", "Position", "first"],
      memberOf: "ui:RowContext.Position", declaration: ["case first"] },
    { id: id.channel, kind: "struct", path: ["Channel"], declaration: ["struct Channel"], doc: "Re-exported copy.", reexported: true },
  ]);
  const uiExtensions = SymbolGraphs.graph("AnyChatUI", [
    { id: "ui:View.listTheme(_:)", kind: "method", path: ["View", "listTheme(_:)"], memberOf: "s:e:View", file: "Environment+Theme.swift",
      declaration: ["func listTheme(_ theme: ", ref("ListTheme", id.listTheme), ") -> some ", ref("View", viewProtocol)] },
  ]);
  const core = SymbolGraphs.graph("AnyChatCore", [
    { id: id.channel, kind: "struct", path: ["Channel"], declaration: ["struct Channel"], doc: "A channel.",
      conformsTo: [
        { id: "s:s8SendableP", fallback: "Swift.Sendable" },
        { id: "s:SH", fallback: "Swift.Hashable" },
        { id: "s:s16SendableMetatypeP", fallback: "Swift.SendableMetatype" },
        id.identified,
      ] },
    { id: id.identified, kind: "protocol", path: ["Identified"], declaration: ["protocol Identified"] },
    { id: "core:Channel.lastKind", kind: "property", path: ["Channel", "lastKind"], memberOf: id.channel, line: 1,
      declaration: ["var lastKind: ", ref("Message.Kind", id.messageKind)] },
    { id: "core:Channel.hash(into:)", kind: "method", path: ["Channel", "hash(into:)"], memberOf: id.channel, line: 2,
      declaration: ["func hash(into hasher: inout Hasher)"], doc: "Hashes the essential components.", docModule: "Swift" },
    { id: id.message, kind: "struct", path: ["Message"], declaration: ["struct Message"] },
    { id: id.messageKind, kind: "enum", path: ["Message", "Kind"], memberOf: id.message, declaration: ["enum Kind"] },
    { id: id.repository, kind: "protocol", path: ["Repository"], declaration: ["protocol Repository"] },
    { id: "core:Repository.load()", kind: "method", path: ["Repository", "load()"], memberOf: id.repository,
      declaration: ["func load() async throws -> ", ref("Page", id.page)] },
    { id: id.page, kind: "struct", path: ["Page"], declaration: ["struct Page"] },
  ]);
  return [ui, uiExtensions, core];
}

function listView(catalog: Catalog): CatalogComponent {
  const component = catalog.components.find((entry) => entry.name === "ListView");
  assert.ok(component);
  return component;
}

const names = (symbols: { name: string }[]) => symbols.map((symbol) => symbol.name);

test("a public view becomes a component with its initializers, slots, callbacks, and settings", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const component = listView(buildCatalog(graphs));

  // Then
  assert.equal(component.doc, "A list.");
  assert.deepEqual(names(component.initializers), ["init(options:)", "init(repository:)"]);
  assert.deepEqual(names(component.slots), ["row(_:)"]);
  assert.deepEqual(names(component.callbacks), ["onSelected(_:)"]);
  assert.deepEqual(names(component.settings), ["title(_:)"]);
  assert.equal(component.initializers[0].declaration, "init(options: ListOptions)");
});

test("the theme and options are found by the screen's naming rule, with all their members", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const component = listView(buildCatalog(graphs));

  // Then
  assert.equal(component.theme?.modifier.declaration, "func listTheme(_ theme: ListTheme) -> some View");
  assert.deepEqual(names(component.theme?.type.members ?? []), ["tint", "light"]);
  assert.deepEqual(names(component.options?.members ?? []), ["isEnabled"]);
});

test("UI types that slots and callbacks receive are context values with their nested types", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const component = listView(buildCatalog(graphs));

  // Then
  assert.deepEqual(names(component.contextValues), ["RowContext"]);
  const [position] = component.contextValues[0].members ?? [];
  assert.equal(position.name, "RowContext.Position");
  assert.deepEqual(names(position.members ?? []), ["first"]);
});

test("domain types are collected through the members that use them, and a nested type brings its outer type", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const catalog = buildCatalog(graphs);

  // Then
  assert.deepEqual(listView(catalog).domainTypes, ["Channel", "Message"]);
  assert.deepEqual(names(catalog.domainTypes), ["Channel", "Message"]);
  assert.equal(catalog.domainTypes[0].doc, "A channel.");
});

test("backend boundary protocols are named but not followed", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const catalog = buildCatalog(graphs);

  // Then
  assert.deepEqual(listView(catalog).backendBoundary, ["Repository"]);
  assert.ok(!names(catalog.domainTypes).includes("Page"));
});

test("documentation inherited from another module is left out", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const channel = buildCatalog(graphs).domainTypes.find((type) => type.name === "Channel");

  // Then
  const hash = channel?.members?.find((member) => member.name === "hash(into:)");
  assert.ok(hash);
  assert.equal(hash.doc, undefined);
});

test("a type lists the protocols it conforms to, without the ones the compiler adds", () => {
  // Given
  const graphs = sdkGraphs();

  // When
  const channel = buildCatalog(graphs).domainTypes.find((type) => type.name === "Channel");

  // Then
  assert.deepEqual(channel?.conformances, ["Hashable", "Identified", "Sendable"]);
});
