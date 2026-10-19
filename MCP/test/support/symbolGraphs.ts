import type { GraphSymbol, SymbolGraph } from "../../scripts/catalog.js";

type Fragment = string | { type: string; id: string };

export interface SymbolSpec {
  id: string;
  kind: string;
  path: string[];
  declaration: Fragment[];
  doc?: string;
  docModule?: string;
  file?: string;
  line?: number;
  memberOf?: string;
  /** Protocols of this graph by identifier, or protocols of another module with the name the graph gives them. */
  conformsTo?: (string | { id: string; fallback: string })[];
  reexported?: boolean;
}

export const SymbolGraphs = {
  viewProtocol: "s:7SwiftUI4ViewP",

  /** A type reference inside a declaration. */
  ref(type: string, id: string): Fragment {
    return { type, id };
  },

  graph(module: string, specs: SymbolSpec[]): SymbolGraph {
    return {
      module: { name: module },
      symbols: specs.map((spec) => symbol(module, spec)),
      relationships: specs.flatMap((spec) => [
        ...(spec.memberOf ? [{ kind: "memberOf", source: spec.id, target: spec.memberOf }] : []),
        ...(spec.conformsTo ?? []).map((target) =>
          typeof target === "string"
            ? { kind: "conformsTo", source: spec.id, target }
            : { kind: "conformsTo", source: spec.id, target: target.id, targetFallback: target.fallback },
        ),
      ]),
    };
  },
};

function symbol(module: string, spec: SymbolSpec): GraphSymbol {
  const file = `file:///Package/Sources/${module}/${spec.file ?? `${spec.path[0]}.swift`}`;
  return {
    kind: { identifier: `swift.${spec.kind}` },
    identifier: { precise: spec.id },
    pathComponents: spec.path,
    declarationFragments: spec.declaration.map((fragment) =>
      typeof fragment === "string" ? { spelling: fragment } : { spelling: fragment.type, preciseIdentifier: fragment.id },
    ),
    docComment: spec.doc === undefined
      ? undefined
      : { module: spec.docModule ?? module, lines: spec.doc.split("\n").map((text) => ({ text })) },
    location: spec.reexported ? undefined : { uri: file, position: { line: spec.line ?? 0, character: 4 } },
  };
}
