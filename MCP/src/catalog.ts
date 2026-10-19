import { existsSync, readFileSync } from "node:fs";
import { renderDemoList, type Demo } from "./demos.js";

export interface CatalogSymbol {
  kind: string;
  name: string;
  declaration: string;
  conformances?: string[];
  doc?: string;
  members?: CatalogSymbol[];
}

export interface CatalogComponent {
  name: string;
  declaration: string;
  doc?: string;
  initializers: CatalogSymbol[];
  slots: CatalogSymbol[];
  callbacks: CatalogSymbol[];
  settings: CatalogSymbol[];
  theme?: { modifier: CatalogSymbol; type: CatalogSymbol };
  options?: CatalogSymbol;
  contextValues: CatalogSymbol[];
  domainTypes: string[];
  backendBoundary: string[];
}

export interface Catalog {
  components: CatalogComponent[];
  domainTypes: CatalogSymbol[];
}

const catalogDirectory = new URL("../../catalog/", import.meta.url);

/** The catalog generated from the SDK's public API, shipped next to the server. */
export function readCatalog(): Catalog {
  return JSON.parse(readFileSync(new URL("components.json", catalogDirectory), "utf8"));
}

/** The hand-written placement example of a component in the catalog. */
export function readPlacementExample(componentName: string): string | undefined {
  const file = new URL(`examples/${componentName}.swift`, catalogDirectory);
  return existsSync(file) ? readFileSync(file, "utf8") : undefined;
}

export function renderComponentList(catalog: Catalog): string {
  return [
    "# AnyChat components",
    "",
    ...catalog.components.map((component) => `- \`${component.name}\`: ${firstSentence(component.doc)}`),
    "",
    "Call `describe_component` with one of these names for its initializers, slots, callbacks, theme, options, and a placement example.",
  ].join("\n");
}

export function renderUnknownComponent(catalog: Catalog, name: string): string {
  const names = catalog.components.map((component) => `\`${component.name}\``).join(", ");
  return `There is no component named \`${name}\`. The components are ${names}.`;
}

export function renderComponent(
  catalog: Catalog,
  component: CatalogComponent,
  placementExample: string | undefined,
  demos: Demo[],
): string {
  const domainTypes = component.domainTypes.flatMap((name) => catalog.domainTypes.find((type) => type.name === name) ?? []);
  const sections = [
    `# \`${component.name}\`\n\n${component.doc ?? ""}`,
    section("Initializers", undefined, component.initializers),
    section("Slots", "Modifiers that replace part of the view with your own view.", component.slots),
    section("Callbacks", "Modifiers that report events.", component.callbacks),
    section("Settings", undefined, component.settings),
    component.theme &&
      section("Theme", "Apply it with the modifier, on this view or on any view above it.", [
        component.theme.modifier,
        component.theme.type,
      ]),
    component.options && section("Options", undefined, [component.options]),
    section("Context values", "Values that the slots and callbacks receive.", component.contextValues),
    section(
      "Domain types",
      "Types the declarations above use. They come from `AnyChatCore`, which `import AnyChatUI` makes available.",
      domainTypes,
    ),
    component.backendBoundary.length > 0 &&
      `## Backend boundary\n\nNot described here: ${component.backendBoundary.map((name) => `\`${name}\``).join(", ")}. Backend adapters implement the backend boundary. An app shows this view with a backend registered through \`.chatBackend(_:)\`, which \`get_started\` sets up.`,
    placementExample !== undefined &&
      `## Placement example\n\nWhere the view goes in an app. Adapt the names to the app.\n\n\`\`\`swift\n${placementExample.trimEnd()}\n\`\`\``,
    demos.length > 0 &&
      `## Demos\n\nShowcase demos that use this view together with other parts. Call \`show_demo\` with a name for its source.\n\n${renderDemoList(demos)}`,
  ];
  return sections.filter((text) => typeof text === "string" && text.length > 0).join("\n\n");
}

function section(title: string, summary: string | undefined, symbols: CatalogSymbol[]): string | undefined {
  if (symbols.length === 0) return undefined;
  const body = symbols.map((symbol) => swiftInterface(symbol, "").join("\n")).join("\n\n");
  return [`## ${title}`, ...(summary ? [summary] : []), `\`\`\`swift\n${body}\n\`\`\``].join("\n\n");
}

function swiftInterface(symbol: CatalogSymbol, indent: string): string[] {
  const doc = (symbol.doc?.split("\n") ?? []).map((line) => `${indent}///${line ? ` ${line}` : ""}`);
  const members = symbol.members ?? [];
  const declaration = symbol.conformances ? `${symbol.declaration}: ${symbol.conformances.join(", ")}` : symbol.declaration;
  if (members.length === 0) return [...doc, `${indent}${declaration}`];

  const body = members.flatMap((member, index) => {
    const previous = members[index - 1];
    const separated = previous !== undefined && (previous.doc !== undefined || member.doc !== undefined);
    return [...(separated ? [""] : []), ...swiftInterface(member, `${indent}    `)];
  });
  return [...doc, `${indent}${declaration} {`, ...body, `${indent}}`];
}

export function firstSentence(doc: string | undefined): string {
  const paragraph = (doc ?? "").split("\n\n")[0].replaceAll("\n", " ");
  return paragraph.match(/^.*?[.!?](?=\s|$)/)?.[0] ?? paragraph;
}
