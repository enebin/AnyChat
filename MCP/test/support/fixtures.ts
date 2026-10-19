import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import type { Catalog, CatalogComponent, CatalogSymbol } from "../../src/catalog.js";
import type { ProjectInspection } from "../../src/project.js";

export const Fixture = {
  sdkVersion: "1.2.3",

  /** Creates a temporary directory holding `files`, keyed by relative path. */
  directory(files: Record<string, string>): string {
    const root = mkdtempSync(join(tmpdir(), "anychat-mcp-"));
    for (const [path, contents] of Object.entries(files)) {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), contents);
    }
    return root;
  },

  /** Copies a checked-in Xcode 26 app project (`App` and `AppTests` targets) and returns its `.xcodeproj` path. */
  xcodeProject(layout: "synchronized" | "listed", files: Record<string, string> = {}): string {
    const root = Fixture.directory(files);
    cpSync(new URL(`../../../test/fixtures/${layout}`, import.meta.url), root, { recursive: true });
    return join(root, "App.xcodeproj");
  },

  /** Copies an existing app (the synchronized Xcode 26 project plus `fixtures/apps/<name>`) and returns its directory. */
  existingApp(name: "tabs" | "navigation"): string {
    const root = Fixture.directory({});
    cpSync(new URL("../../../test/fixtures/synchronized", import.meta.url), root, { recursive: true });
    cpSync(new URL(`../../../test/fixtures/apps/${name}`, import.meta.url), root, { recursive: true });
    // New Xcode 26 projects set this, so a file sees another module's members only when it imports that module.
    const pbxproj = join(root, "App.xcodeproj", "project.pbxproj");
    writeFileSync(
      pbxproj,
      readFileSync(pbxproj, "utf8").replaceAll(
        "IPHONEOS_DEPLOYMENT_TARGET = 18.0;",
        "IPHONEOS_DEPLOYMENT_TARGET = 18.0;\n\t\t\t\tSWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;",
      ),
    );
    return root;
  },

  pbxproj(
    options: {
      deploymentTargets?: string[];
      dependsOnSDK?: boolean;
      synchronized?: boolean;
      listedFiles?: string[];
      uiTestTarget?: boolean;
    } = {},
  ): string {
    const targets = (options.deploymentTargets ?? []).map((target) => `IPHONEOS_DEPLOYMENT_TARGET = ${target};`);
    const dependency = options.dependsOnSDK ? ["productName = AnyChatUI;"] : [];
    const synchronized = options.synchronized ? ["isa = PBXFileSystemSynchronizedRootGroup;"] : [];
    const files = (options.listedFiles ?? []).map((name) => `isa = PBXFileReference; path = ${name};`);
    const uiTestTarget = options.uiTestTarget ? ['productType = "com.apple.product-type.bundle.ui-testing";'] : [];
    return [...targets, ...dependency, ...synchronized, ...files, ...uiTestTarget].join("\n");
  },

  inspection(overrides: Partial<ProjectInspection> = {}): ProjectInspection {
    return {
      kind: "xcodeProject",
      projectPath: "/App/App.xcodeproj",
      iosDeploymentTarget: "18.0",
      dependsOnSDK: true,
      generatorSpec: undefined,
      compilesNewFiles: true,
      implementsBackend: true,
      registersBackend: true,
      placesChannelList: true,
      channelListScreen: "ChatScreen",
      opensChannelList: true,
      hasUITestTarget: true,
      hasChatUITest: true,
      ...overrides,
    };
  },

  catalogSymbol(name: string, overrides: Partial<CatalogSymbol> = {}): CatalogSymbol {
    return { kind: "method", name, declaration: `func ${name}`, doc: `Documents ${name}.`, ...overrides };
  },

  /** A catalog with one component, `ListView`, that has one symbol in every part except settings. */
  catalog(component: Partial<CatalogComponent> = {}): Catalog {
    const symbol = Fixture.catalogSymbol;
    return {
      components: [
        {
          name: "ListView",
          declaration: "struct ListView",
          doc: "A list of channels. It loads from the backend.\n\nMore detail.",
          initializers: [symbol("init()", { kind: "init", declaration: "init()" })],
          slots: [symbol("row(_:)", { declaration: "func row(_ content: @escaping (Channel) -> some View) -> ListView" })],
          callbacks: [symbol("onSelected(_:)")],
          settings: [],
          theme: {
            modifier: symbol("listTheme(_:)", { declaration: "func listTheme(_ theme: ListTheme) -> some View" }),
            type: symbol("ListTheme", {
              kind: "struct",
              declaration: "struct ListTheme",
              members: [symbol("tint", { kind: "property", declaration: "var tint: Color", doc: undefined })],
            }),
          },
          options: symbol("ListOptions", { kind: "struct", declaration: "struct ListOptions", members: [] }),
          contextValues: [symbol("RowContext", { kind: "struct", declaration: "struct RowContext", members: [] })],
          domainTypes: ["Channel"],
          backendBoundary: ["ListRepository"],
          ...component,
        },
      ],
      domainTypes: [
        symbol("Channel", {
          kind: "struct",
          declaration: "struct Channel",
          conformances: ["Hashable", "Sendable"],
          members: [
            symbol("Channel.Kind", {
              kind: "enum",
              declaration: "enum Kind",
              doc: undefined,
              members: [
                symbol("direct", { kind: "enum.case", declaration: "case direct", doc: undefined }),
                symbol("group", { kind: "enum.case", declaration: "case group", doc: undefined }),
              ],
            }),
            symbol("name", { kind: "property", declaration: "var name: String", doc: "The name.\n\n- Since: 1.0.0" }),
          ],
        }),
      ],
    };
  },
};
