import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";
import { compareVersions, inspectProject } from "../src/project.js";
import { Fixture } from "./support/fixtures.js";

test("an Xcode project reports its lowest deployment target and the SDK dependency", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ deploymentTargets: ["18.0", "17.4", "\"18.2\""], dependsOnSDK: true }),
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.kind, "xcodeProject");
  assert.equal(result.inspection.projectPath, join(root, "App.xcodeproj"));
  assert.equal(result.inspection.iosDeploymentTarget, "17.4");
  assert.equal(result.inspection.dependsOnSDK, true);
});

test("a fresh Xcode project has no setup steps done", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj(),
    "App/AppApp.swift": "@main struct AppApp: App {}",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.iosDeploymentTarget, undefined);
  assert.equal(result.inspection.dependsOnSDK, false);
  assert.equal(result.inspection.implementsBackend, false);
  assert.equal(result.inspection.registersBackend, false);
  assert.equal(result.inspection.placesChannelList, false);
  assert.equal(result.inspection.opensChannelList, false);
  assert.equal(result.inspection.hasUITestTarget, false);
  assert.equal(result.inspection.hasChatUITest, false);
});

test("a UI test target and a test that sends a message are reported", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true, uiTestTarget: true }),
    "AppUITests/ChatUITests.swift": 'let app = XCUIApplication()\napp.buttons["Send"].tap()',
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.hasUITestTarget, true);
  assert.equal(result.inspection.hasChatUITest, true);
});

test("a UI test that sends nothing, or one a listing project does not compile, is not the chat UI test", () => {
  // Given
  const launchOnly = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true, uiTestTarget: true }),
    "AppUITests/AppUITests.swift": "let app = XCUIApplication()\napp.launch()",
  });
  const unlisted = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ uiTestTarget: true, listedFiles: ["AppUITests.swift"] }),
    "AppUITests/ChatUITests.swift": 'let app = XCUIApplication()\napp.buttons["Send"].tap()',
  });

  // When
  const results = [launchOnly, unlisted].map((root) => inspectProject(root));

  // Then
  for (const result of results) {
    assert.ok(result.found);
    assert.equal(result.inspection.hasChatUITest, false);
  }
});

test("the app's Swift sources reveal the backend, its registration, the chat screen, and its entry point", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/Backend.swift": "final class MyBackend: NSObject, ChatBackend {}",
    "App/AppApp.swift": "ContentView().chatBackend(backend)",
    "App/Chat/ChatScreen.swift": "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/Views/ContentView.swift": "TabView { Tab(\"Chat\", systemImage: \"bubble\") { ChatScreen() } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.implementsBackend, true);
  assert.equal(result.inspection.registersBackend, true);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, true);
});

test("the chat screen's own declaration, its previews, and comments are not an entry point", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": [
      "struct ChatScreen: View {",
      "    var body: some View { NavigationStack { ChannelListView() } }",
      "    static func make() -> ChatScreen { ChatScreen() }",
      "}",
      "// Open it with ChatScreen() from a tab.",
      "/* ChatScreen() */",
      "#Preview { ChatScreen() }",
    ].join("\n"),
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, false);
});

test("an entry point in the same file as the pasted chat screen counts", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ listedFiles: ["AppApp.swift"] }),
    "App/AppApp.swift": [
      "@main struct AppApp: App { var body: some Scene { WindowGroup { RootView() } } }",
      "struct RootView: View { var body: some View { TabView { Tab(\"Chat\", systemImage: \"bubble\") { ChatScreen() } } } }",
      "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    ].join("\n"),
    "App/Unlisted.swift": "struct Other: View { var body: some View { ChatScreen() } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, true);
});

test("a chat screen in a file a listing project does not compile is not counted, nor is opening it", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ listedFiles: ["AppApp.swift"] }),
    "App/AppApp.swift": "@main struct AppApp: App { var body: some Scene { WindowGroup { ChatScreen() } } }",
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { ChannelListView() } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, false);
  assert.equal(result.inspection.opensChannelList, false);
});

test("an entry point after a string that contains // still counts", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/HelpView.swift": 'struct HelpView: View { var body: some View { VStack { Link("Help", destination: URL(string: "https://example.com")!); ChatScreen() } } }',
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.opensChannelList, true);
});

test("an entry point after a raw string that contains // and a brace still counts", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/HelpView.swift": 'struct HelpView: View { var body: some View { VStack { Text(#"See "https://example.com" {"#); ChatScreen() } } }',
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.opensChannelList, true);
});

test("a multi-line string and a nested block comment are not an entry point", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/HelpView.swift": [
      "struct HelpView: View {",
      '    let help = """',
      "    } Open ChatScreen() from a tab.",
      '    """',
      "    /* outer /* inner */ ChatScreen() */",
      "    var body: some View { Text(help) }",
      "}",
    ].join("\n"),
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.opensChannelList, false);
});

test("a chat screen with another name is reported by name for the entry point step", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { Text(\"Contact support\") } }",
    "App/ChannelsScreen.swift": "struct ChannelsScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.channelListScreen, "ChannelsScreen");
  assert.equal(result.inspection.opensChannelList, false);
});

test("a channel list in an extension of a type the app does not declare names no screen", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatSheet.swift": "extension View { func chatSheet(_ isPresented: Binding<Bool>) -> some View { sheet(isPresented: isPresented) { ChannelListView() } } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.channelListScreen, undefined);
});

test("a channel list in an extension of a type the app declares names that type", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChannelsScreen+List.swift": "extension ChannelsScreen { var list: some View { ChannelListView() } }",
    "App/ChannelsScreen.swift": "struct ChannelsScreen: View { var body: some View { list } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.channelListScreen, "ChannelsScreen");
});

test("a name that only ends with the chat screen's name is not an entry point", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/RootView.swift": "struct RootView: View { var body: some View { TabView { Tab(\"Main\", systemImage: \"house\") { MainChatScreen() } } } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, false);
});

test("an app's own screen named ChatScreen without the channel list is not the chat screen", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/ChatScreen.swift": "struct ChatScreen: View { var body: some View { Text(\"Contact support\") } }",
    "App/SettingsView.swift": "struct SettingsView: View { var body: some View { NavigationLink(\"Support\") { ChatScreen() } } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, false);
  assert.equal(result.inspection.opensChannelList, false);
});

test("a channel list the app placed in its own opened view counts as the chat screen and its entry point", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/InboxView.swift": "struct InboxView: View { var body: some View { NavigationStack { ChannelListView() } } }",
    "App/RootView.swift": "struct RootView: View { var body: some View { TabView { Tab(\"Inbox\", systemImage: \"tray\") { InboxView() } } } }",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, true);
});

for (const conformance of ["App", "SwiftUI.App"]) test(`a channel list at the root of an app that conforms to ${conformance} is opened`, () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }),
    "App/AppApp.swift": `@main struct AppApp: ${conformance} { var body: some Scene { WindowGroup { NavigationStack { ChannelListView() } } } }`,
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.placesChannelList, true);
  assert.equal(result.inspection.opensChannelList, true);
});

test("sources in build output and dependency checkouts are ignored", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj(),
    ".build/checkouts/swiftuikit/Examples/ChatScreen.swift": "struct ChatScreen: View {}\nChatScreen().chatBackend(backend)",
    "DerivedData/SourcePackages/Backend.swift": "final class SampleChatBackend: ChatBackend {}",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.implementsBackend, false);
  assert.equal(result.inspection.registersBackend, false);
  assert.equal(result.inspection.placesChannelList, false);
});

test("a Swift package reports its platform and the SDK product", () => {
  // Given
  const root = Fixture.directory({
    "Package.swift": `platforms: [.iOS(.v17_4)], targets: [.target(name: "Chat", dependencies: [.product(name: "AnyChatUI", package: "swiftuikit")])]`,
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.kind, "swiftPackage");
  assert.equal(result.inspection.iosDeploymentTarget, "17.4");
  assert.equal(result.inspection.dependsOnSDK, true);
});

test("a string platform version is read as written", () => {
  // Given
  const root = Fixture.directory({ "Package.swift": `platforms: [.iOS("18.1")]` });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.iosDeploymentTarget, "18.1");
});

test("a project in a subdirectory is found", () => {
  // Given
  const root = Fixture.directory({ "ios/App.xcodeproj/project.pbxproj": Fixture.pbxproj() });

  // When
  const result = inspectProject(root);

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.projectPath, join(root, "ios", "App.xcodeproj"));
});

test("several projects are returned as candidates instead of guessing", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj(),
    "Package.swift": "",
  });

  // When
  const result = inspectProject(root);

  // Then
  assert.deepEqual(result, { found: false, candidates: [join(root, "App.xcodeproj"), join(root, "Package.swift")] });
});

test("an explicit project path picks that project among several", () => {
  // Given
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj(),
    "Package.swift": "",
  });

  // When
  const result = inspectProject(join(root, "App.xcodeproj"));

  // Then
  assert.ok(result.found);
  assert.equal(result.inspection.kind, "xcodeProject");
});

test("a missing path finds nothing", () => {
  // Given
  const root = Fixture.directory({});

  // When
  const results = [inspectProject(join(root, "missing")), inspectProject(join(root, "Missing.xcodeproj"))];

  // Then
  for (const result of results) {
    assert.deepEqual(result, { found: false, candidates: [] });
  }
});

test("versions compare by number, not by text", () => {
  // Given / When / Then
  assert.ok(compareVersions("9.0", "18.0") < 0);
  assert.ok(compareVersions("18", "18.0") === 0);
  assert.ok(compareVersions("18.0.1", "18.0") > 0);
});

test("only a declared conformance counts as a backend", () => {
  // Given
  const conformances = [
    "@MainActor final class InMemoryChatBackend: ChatBackend {}",
    "final class MyBackend: NSObject, ChatBackend {}",
    "extension Adapter.Backend: ChatBackend {}",
  ];
  const mentions = [
    "struct Screen: View { let backend: ChatBackend }",
    "func register(backend: any ChatBackend) {}",
    "struct Screen<Backend: ChatBackend>: View {}",
  ];

  // When
  const isBackend = (source: string) => {
    const result = inspectProject(
      Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }), "App/Source.swift": source }),
    );
    assert.ok(result.found);
    return result.inspection.implementsBackend;
  };

  // Then
  for (const source of conformances) {
    assert.equal(isBackend(source), true, source);
  }
  for (const source of mentions) {
    assert.equal(isBackend(source), false, source);
  }
});

test("a project that lists its files counts a backend only in a listed file", () => {
  // Given
  const backend = { "App/InMemoryChatBackend.swift": "final class InMemoryChatBackend: ChatBackend {}" };
  const unlisted = Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj(), ...backend });
  const listed = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ listedFiles: ["InMemoryChatBackend.swift"] }),
    ...backend,
  });

  // When
  const results = [inspectProject(unlisted), inspectProject(listed)];

  // Then
  const [unlistedResult, listedResult] = results;
  assert.ok(unlistedResult?.found && listedResult?.found);
  assert.equal(unlistedResult.inspection.compilesNewFiles, false);
  assert.equal(unlistedResult.inspection.implementsBackend, false);
  assert.equal(listedResult.inspection.implementsBackend, true);
});

test("a synchronized project and a Swift package compile new files", () => {
  // Given
  const synchronized = Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ synchronized: true }) });
  const swiftPackage = Fixture.directory({ "Package.swift": "" });

  // When
  const results = [inspectProject(synchronized), inspectProject(swiftPackage)];

  // Then
  for (const result of results) {
    assert.ok(result.found);
    assert.equal(result.inspection.compilesNewFiles, true);
  }
});

test("a project generated by XcodeGen or Tuist names its spec", () => {
  // Given
  const roots = [
    Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj(), "project.yml": "" }),
    Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj(), "Project.swift": "" }),
    Fixture.directory({ "App.xcodeproj/project.pbxproj": Fixture.pbxproj() }),
  ];

  // When
  const specs = roots.map((root) => {
    const result = inspectProject(join(root, "App.xcodeproj"));
    assert.ok(result.found);
    return result.inspection.generatorSpec;
  });

  // Then
  assert.deepEqual(specs, ["project.yml", "Project.swift", undefined]);
});
