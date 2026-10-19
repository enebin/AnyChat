import type { Catalog, CatalogComponent, CatalogSymbol } from "../src/catalog.js";

export interface SymbolGraph {
  module: { name: string };
  symbols: GraphSymbol[];
  relationships: { kind: string; source: string; target: string; targetFallback?: string }[];
}

export interface GraphSymbol {
  kind: { identifier: string };
  identifier: { precise: string };
  pathComponents: string[];
  declarationFragments?: { spelling: string; preciseIdentifier?: string }[];
  docComment?: { module?: string; lines: { text: string }[] };
  location?: { uri: string; position: { line: number; character: number } };
}

export const catalogModules = { ui: "AnyChatUI", core: "AnyChatCore" };

const viewProtocol = "s:7SwiftUI4ViewP";
const typeKinds = new Set(["swift.struct", "swift.enum", "swift.class", "swift.actor", "swift.protocol", "swift.typealias"]);
// The compiler adds `SendableMetatype` to every `Sendable` type; the source never spells it.
const implicitConformances = new Set(["SendableMetatype"]);

interface Entry {
  symbol: GraphSymbol;
  module: string;
}

/** Builds the component catalog from the symbol graphs of `AnyChatUI` and `AnyChatCore`. */
export function buildCatalog(graphs: SymbolGraph[]): Catalog {
  const index = new SymbolIndex(graphs);
  const domainTypes = new Map<string, CatalogSymbol>();

  const components = index
    .topLevel(catalogModules.ui)
    .filter((entry) => entry.symbol.kind.identifier === "swift.struct" && index.conformsTo(entry, viewProtocol))
    .map((view) => {
      const component = describeComponent(index, view);
      for (const [id, type] of component.reachedDomainTypes) {
        domainTypes.set(id, type);
      }
      return component.entry;
    });

  return {
    components: sortedByName(components),
    domainTypes: sortedByName([...domainTypes.values()]),
  };
}

function describeComponent(
  index: SymbolIndex,
  view: Entry,
): { entry: CatalogComponent; reachedDomainTypes: Map<string, CatalogSymbol> } {
  const name = view.symbol.pathComponents[0];
  const screen = name.replace(/View$/, "");
  const members = index.members(view.symbol.identifier.precise);
  const initializers = members.filter((member) => member.symbol.kind.identifier === "swift.init");
  const methods = members.filter((member) => member.symbol.kind.identifier === "swift.method");
  const slots = methods.filter((method) => takesViewBuildingClosure(method.symbol));
  const callbacks = methods.filter((method) => !slots.includes(method) && /^on[A-Z]/.test(lastPathComponent(method.symbol)));
  const settings = methods.filter((method) => !slots.includes(method) && !callbacks.includes(method));

  const themeType = index.topLevelNamed(catalogModules.ui, `${screen}Theme`);
  const themeModifier = index.viewExtensionMethod(`${lowerFirst(screen)}Theme`);
  const optionsType = index.topLevelNamed(catalogModules.ui, `${screen}Options`);

  const contextValues = new Map<string, Entry>();
  for (const id of references([...slots, ...callbacks].map((entry) => entry.symbol))) {
    const type = index.outermostType(id);
    if (type && type.module === catalogModules.ui && type !== view) {
      contextValues.set(type.symbol.identifier.precise, type);
    }
  }

  const describedTypes = [themeType, optionsType, ...contextValues.values()].filter((entry) => entry !== undefined);
  const start = [
    ...initializers,
    ...methods,
    ...(themeModifier ? [themeModifier] : []),
    ...describedTypes.flatMap((type) => index.withNestedMembers(type)),
  ];
  const walk = walkDomainTypes(index, start);

  return {
    entry: {
      name,
      declaration: declaration(view.symbol),
      doc: doc(view.symbol),
      initializers: initializers.map(describeMember),
      slots: slots.map(describeMember),
      callbacks: callbacks.map(describeMember),
      settings: settings.map(describeMember),
      theme:
        themeType && themeModifier
          ? { modifier: describeMember(themeModifier), type: describeType(index, themeType) }
          : undefined,
      options: optionsType ? describeType(index, optionsType) : undefined,
      contextValues: sortedByName([...contextValues.values()].map((entry) => describeType(index, entry))),
      domainTypes: [...walk.domainTypes.values()].map((type) => type.name).sort(),
      backendBoundary: [...walk.boundary].sort(),
    },
    reachedDomainTypes: walk.domainTypes,
  };
}

/**
 * Collects the `AnyChatCore` types reachable from `start`, following the types their members use.
 * Protocols are the backend boundary: they are named but not followed, so the adapter contract stays out of the UI catalog.
 */
function walkDomainTypes(index: SymbolIndex, start: Entry[]): { domainTypes: Map<string, CatalogSymbol>; boundary: Set<string> } {
  const domainTypes = new Map<string, CatalogSymbol>();
  const boundary = new Set<string>();
  const pending = [...references(start.map((entry) => entry.symbol))];

  while (pending.length > 0) {
    const type = index.outermostType(pending.pop()!);
    if (!type || type.module !== catalogModules.core) continue;
    const id = type.symbol.identifier.precise;
    if (type.symbol.kind.identifier === "swift.protocol") {
      boundary.add(type.symbol.pathComponents.join("."));
    } else if (!domainTypes.has(id)) {
      domainTypes.set(id, describeType(index, type));
      pending.push(...references(index.withNestedMembers(type).map((entry) => entry.symbol)));
    }
  }
  return { domainTypes, boundary };
}

function describeType(index: SymbolIndex, type: Entry): CatalogSymbol {
  const conformances = index.conformanceNames(type).filter((name) => !implicitConformances.has(name));
  return {
    kind: kindName(type.symbol),
    name: type.symbol.pathComponents.join("."),
    declaration: declaration(type.symbol),
    conformances: conformances.length > 0 ? conformances : undefined,
    doc: doc(type.symbol),
    members: index.members(type.symbol.identifier.precise).map((member) =>
      typeKinds.has(member.symbol.kind.identifier) ? describeType(index, member) : describeMember(member),
    ),
  };
}

function describeMember(member: Entry): CatalogSymbol {
  return {
    kind: kindName(member.symbol),
    name: lastPathComponent(member.symbol),
    declaration: declaration(member.symbol),
    doc: doc(member.symbol),
  };
}

class SymbolIndex {
  private readonly entries = new Map<string, Entry>();
  private readonly parents = new Map<string, string>();
  private readonly children = new Map<string, Set<string>>();
  private readonly conformances = new Map<string, Set<string>>();
  private readonly externalNames = new Map<string, string>();

  constructor(graphs: SymbolGraph[]) {
    // A module re-exports the symbols of the modules it `@_exported import`s without a location; the home copy has one.
    for (const graph of graphs) {
      for (const symbol of graph.symbols) {
        if (symbol.location && !symbol.identifier.precise.includes("::SYNTHESIZED::")) {
          this.entries.set(symbol.identifier.precise, { symbol, module: graph.module.name });
        }
      }
    }
    for (const graph of graphs) {
      for (const { kind, source, target, targetFallback } of graph.relationships) {
        if (!this.entries.has(source)) continue;
        if (kind === "memberOf") {
          this.parents.set(source, target);
          setFor(this.children, target).add(source);
        } else if (kind === "conformsTo") {
          setFor(this.conformances, source).add(target);
          if (targetFallback) this.externalNames.set(target, targetFallback.split(".").pop()!);
        }
      }
    }
  }

  topLevel(module: string): Entry[] {
    return [...this.entries.entries()]
      .filter(([id, entry]) => entry.module === module && !this.parents.has(id))
      .map(([, entry]) => entry);
  }

  topLevelNamed(module: string, name: string): Entry | undefined {
    return this.topLevel(module).find(
      (entry) => typeKinds.has(entry.symbol.kind.identifier) && entry.symbol.pathComponents.join(".") === name,
    );
  }

  viewExtensionMethod(baseName: string): Entry | undefined {
    return [...this.entries.values()].find(
      (entry) =>
        entry.module === catalogModules.ui &&
        entry.symbol.kind.identifier === "swift.method" &&
        entry.symbol.pathComponents.length === 2 &&
        entry.symbol.pathComponents[0] === "View" &&
        lastPathComponent(entry.symbol).startsWith(`${baseName}(`),
    );
  }

  conformsTo(entry: Entry, protocol: string): boolean {
    return this.conformances.get(entry.symbol.identifier.precise)?.has(protocol) ?? false;
  }

  /** The names of the protocols `entry` conforms to, sorted, since the graph does not keep their source order. */
  conformanceNames(entry: Entry): string[] {
    return [...(this.conformances.get(entry.symbol.identifier.precise) ?? [])]
      .flatMap((id) => this.entries.get(id)?.symbol.pathComponents.join(".") ?? this.externalNames.get(id) ?? [])
      .sort();
  }

  /** Public members in source order, the ones declared next to the type first. */
  members(id: string): Entry[] {
    const parentFile = this.entries.get(id)?.symbol.location?.uri;
    return [...(this.children.get(id) ?? [])]
      .flatMap((child) => this.entries.get(child) ?? [])
      .sort((a, b) => compareLocations(a.symbol, b.symbol, parentFile));
  }

  withNestedMembers(type: Entry): Entry[] {
    return [type, ...this.members(type.symbol.identifier.precise).flatMap((member) => this.withNestedMembers(member))];
  }

  /** The top-level type that declares `id`, or `undefined` when `id` is not one of ours. */
  outermostType(id: string): Entry | undefined {
    let current = id;
    while (this.parents.has(current) && this.entries.has(this.parents.get(current)!)) {
      current = this.parents.get(current)!;
    }
    const entry = this.entries.get(current);
    return entry && typeKinds.has(entry.symbol.kind.identifier) ? entry : undefined;
  }
}

function takesViewBuildingClosure(symbol: GraphSymbol): boolean {
  // The method returns its own view type, so a `View` in the declaration can only come from a parameter.
  return (symbol.declarationFragments ?? []).some((fragment) => fragment.preciseIdentifier === viewProtocol);
}

function references(symbols: GraphSymbol[]): string[] {
  return symbols.flatMap((symbol) =>
    (symbol.declarationFragments ?? []).flatMap((fragment) => fragment.preciseIdentifier ?? []),
  );
}

function declaration(symbol: GraphSymbol): string {
  return (symbol.declarationFragments ?? []).map((fragment) => fragment.spelling).join("").trim();
}

function doc(symbol: GraphSymbol): string | undefined {
  const comment = symbol.docComment;
  // Members that implement a standard library protocol inherit its documentation, which is not ours to show.
  if (!comment || (comment.module && !Object.values(catalogModules).includes(comment.module))) return undefined;
  return comment.lines.map((line) => line.text).join("\n");
}

function kindName(symbol: GraphSymbol): string {
  return symbol.kind.identifier.replace(/^swift\./, "");
}

function lastPathComponent(symbol: GraphSymbol): string {
  return symbol.pathComponents[symbol.pathComponents.length - 1];
}

function lowerFirst(text: string): string {
  return text.charAt(0).toLowerCase() + text.slice(1);
}

function compareLocations(a: GraphSymbol, b: GraphSymbol, preferredFile: string | undefined): number {
  const aFile = a.location?.uri ?? "";
  const bFile = b.location?.uri ?? "";
  if (aFile !== bFile) {
    if (aFile === preferredFile) return -1;
    if (bFile === preferredFile) return 1;
    return aFile < bFile ? -1 : 1;
  }
  const aPosition = a.location?.position ?? { line: 0, character: 0 };
  const bPosition = b.location?.position ?? { line: 0, character: 0 };
  return aPosition.line - bPosition.line || aPosition.character - bPosition.character;
}

function sortedByName<T extends { name: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

function setFor<K, V>(map: Map<K, Set<V>>, key: K): Set<V> {
  let set = map.get(key);
  if (!set) {
    set = new Set();
    map.set(key, set);
  }
  return set;
}
