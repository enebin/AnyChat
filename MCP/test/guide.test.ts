import assert from "node:assert/strict";
import { test } from "node:test";
import { renderAddPackage, renderGetStarted, repositoryURL, setupSteps } from "../src/guide.js";
import { Fixture } from "./support/fixtures.js";

test("a fully set up project has every step done", () => {
  // Given
  const inspection = Fixture.inspection();

  // When
  const statuses = setupSteps(inspection, Fixture.sdkVersion).map((step) => step.status);

  // Then
  assert.deepEqual(statuses, ["done", "done", "done", "done", "done", "done"]);
});

test("each missing piece leaves its own step to do", () => {
  // Given
  const inspection = Fixture.inspection({
    iosDeploymentTarget: "17.0",
    dependsOnSDK: false,
    implementsBackend: false,
    registersBackend: false,
    placesChannelList: false,
    opensChannelList: false,
  });

  // When
  const statuses = setupSteps(inspection, Fixture.sdkVersion).map((step) => step.status);

  // Then
  assert.deepEqual(statuses, ["todo", "todo", "todo", "todo", "todo", "todo"]);
});

test("an undeclared deployment target is unknown rather than done", () => {
  // Given
  const inspection = Fixture.inspection({ iosDeploymentTarget: undefined });

  // When
  const [deploymentTarget] = setupSteps(inspection, Fixture.sdkVersion);

  // Then
  assert.equal(deploymentTarget!.status, "unknown");
});

test("a low deployment target asks for every entry to be raised, not just the app target's", () => {
  // Given
  const inspection = Fixture.inspection({ iosDeploymentTarget: "17.0" });

  // When
  const [deploymentTarget] = setupSteps(inspection, Fixture.sdkVersion);

  // Then
  assert.match(deploymentTarget!.instructions, /The project targets iOS 17\.0\./);
  assert.match(deploymentTarget!.instructions, /raise every `IPHONEOS_DEPLOYMENT_TARGET` below `18\.0`/);
  assert.match(deploymentTarget!.instructions, /project-level settings and every target's/);
});

test("an undeclared deployment target says none was found", () => {
  // Given
  const inspection = Fixture.inspection({ iosDeploymentTarget: undefined });

  // When
  const [deploymentTarget] = setupSteps(inspection, Fixture.sdkVersion);

  // Then
  assert.match(deploymentTarget!.instructions, /^No iOS deployment target was found\./);
});

test("a project that lists its files gets the backend pasted into an existing file", () => {
  // Given
  const inspection = Fixture.inspection({ compilesNewFiles: false, implementsBackend: false });

  // When
  const backend = setupSteps(inspection, Fixture.sdkVersion)[2]!;

  // Then
  assert.match(backend.instructions, /Do not create a file and do not add one to `project\.pbxproj`/);
  assert.match(backend.instructions, /already in the app target/);
  assert.doesNotMatch(backend.instructions, /Add this file/);
});

test("an Xcode project is pointed at the add_package tool", () => {
  // Given
  const inspection = Fixture.inspection({ dependsOnSDK: false });

  // When
  const dependency = setupSteps(inspection, Fixture.sdkVersion)[1]!;

  // Then
  assert.match(dependency.instructions, /^Call the add_package tool with projectPath `\/App\/App\.xcodeproj`\. The project can stay open in Xcode\./);
  assert.doesNotMatch(dependency.instructions, /close the project/);
  assert.match(dependency.instructions, /Do not edit `project\.pbxproj` by hand/);
});

test("a generated Xcode project is told to edit its spec instead", () => {
  // Given
  const xcodeGen = Fixture.inspection({ dependsOnSDK: false, generatorSpec: "project.yml" });
  const tuist = Fixture.inspection({ dependsOnSDK: false, generatorSpec: "Project.swift" });

  // When
  const [xcodeGenStep, tuistStep] = [xcodeGen, tuist].map((inspection) => setupSteps(inspection, Fixture.sdkVersion)[1]!);

  // Then
  assert.ok(xcodeGenStep!.instructions.includes(`packages:\n  anychat:\n    url: ${repositoryURL}\n    from: ${Fixture.sdkVersion}`));
  assert.match(xcodeGenStep!.instructions, /run `xcodegen generate`/);
  assert.match(tuistStep!.instructions, /from `Project\.swift`.*run `tuist generate`/s);
  assert.match(xcodeGenStep!.instructions, /^First ask the user to confirm that the project is still generated from `project\.yml`: running `xcodegen generate`/);
  assert.match(tuistStep!.instructions, /^First ask the user to confirm that the project is still generated from `Project\.swift`: running `tuist generate`/);
  for (const step of [xcodeGenStep!, tuistStep!]) {
    assert.doesNotMatch(step.instructions, /add_package/);
    assert.ok(step.instructions.includes(`File > Add Package Dependencies…, enter \`${repositoryURL}\`, choose Up to Next Major Version from \`${Fixture.sdkVersion}\``));
  }
});

test("a Swift package gets the manifest lines pinned to the guided SDK version", () => {
  // Given
  const inspection = Fixture.inspection({ kind: "swiftPackage", dependsOnSDK: false });

  // When
  const dependency = setupSteps(inspection, Fixture.sdkVersion)[1]!;

  // Then
  assert.ok(dependency.instructions.includes(`.package(url: "${repositoryURL}", from: "${Fixture.sdkVersion}")`));
  assert.ok(dependency.instructions.includes(`.product(name: "AnyChatUI", package: "anychat")`));
});

test("the guide shows only the first unfinished step's instructions", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ registersBackend: false, placesChannelList: false, opensChannelList: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, false);

  // Then
  assert.match(text, /## Next step: 5\. Register the backend at the app root/);
  assert.match(text, /\.chatBackend\(backend\)/);
  assert.doesNotMatch(text, /NavigationStack/);
});

test("the entry point step opens the chat screen by the name the project gave it", () => {
  // Given
  const inspection = Fixture.inspection({ opensChannelList: false, channelListScreen: "ChannelsScreen" });

  // When
  const entryPoint = setupSteps(inspection, Fixture.sdkVersion)[5]!;

  // Then
  assert.ok(entryPoint.instructions.startsWith("Open `ChannelsScreen()` from the app's existing UI"));
  assert.match(entryPoint.instructions, /presents `ChannelsScreen` as a sheet/);
  assert.match(entryPoint.instructions, /```swift\nTab\("Chat", systemImage: "bubble\.left\.and\.bubble\.right"\) \{\n    ChannelsScreen\(\)/);
  assert.doesNotMatch(entryPoint.instructions, /\bChatScreen\b/);
});

test("the entry point step falls back to the chat screen's default name when no screen type was found", () => {
  // Given
  const inspection = Fixture.inspection({ opensChannelList: false, channelListScreen: undefined });

  // When
  const entryPoint = setupSteps(inspection, Fixture.sdkVersion)[5]!;

  // Then
  assert.ok(entryPoint.instructions.startsWith("Open `ChatScreen()`, or the view that shows `ChannelListView` if it has another name, from"));
  assert.match(entryPoint.instructions, /presents `ChatScreen` as a sheet/);
});

test("a finished setup says so and names no next step", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection() };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, false);

  // Then
  assert.match(text, /Every step is done/);
  assert.match(text, /Apple system colors, SF Symbols, and Dynamic Type/);
  assert.doesNotMatch(text, /Next step/);
});

test("several candidates are listed for the user to choose from", () => {
  // Given
  const result = { found: false as const, candidates: ["/App/App.xcodeproj", "/App/Package.swift"] };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, false);

  // Then
  assert.match(text, /Ask the user which one/);
  assert.ok(text.includes("- `/App/App.xcodeproj`"));
  assert.ok(text.includes("- `/App/Package.swift`"));
});

test("no project tells the agent where to point instead", () => {
  // Given
  const result = { found: false as const, candidates: [] };

  // When
  const text = renderGetStarted(result, "/Empty", Fixture.sdkVersion, false);

  // Then
  assert.match(text, /No `\.xcodeproj` or `Package\.swift` was found in `\/Empty`/);
});

test("each add_package outcome tells the agent what to do next", () => {
  // Given
  const project = "/App/App.xcodeproj";

  // When
  const text = (result: Parameters<typeof renderAddPackage>[0]) => renderAddPackage(result, project, Fixture.sdkVersion);

  // Then
  assert.match(text({ status: "linked", targetName: "App", reusedReference: false }), /Linked the `AnyChatUI` product into the `App` target.*Call get_started again/);
  assert.match(text({ status: "linked", targetName: "App", reusedReference: false }), /must choose the version on disk; keeping Xcode's version writes the project back without the package/);
  assert.match(text({ status: "linked", targetName: "App", reusedReference: true }), /only the product was added/);
  assert.match(text({ status: "alreadyLinked", targetName: "App" }), /already links `AnyChatUI`\. Nothing changed\./);
  assert.match(text({ status: "chooseTarget", candidates: ["App", "Widget"] }), /Ask the user which target.*\n\n- `App`\n- `Widget`/s);
  assert.match(text({ status: "notFound" }), /No `project\.pbxproj` was found in `\/App\/App\.xcodeproj`/);
  assert.match(text({ status: "generated", specFile: "project.yml" }), /generated from `project\.yml`.*Nothing changed/);
  assert.match(text({ status: "generated", specFile: "project.yml" }), /First ask the user to confirm that the project is still generated from `project\.yml`/);
  assert.match(text({ status: "invalid", reason: "lint failed" }), /Nothing changed.*\(lint failed\).*File > Add Package Dependencies/);
});

test("registering the backend edits the existing App and adds the import with it", () => {
  // Given
  const inspection = Fixture.inspection({ registersBackend: false });

  // When
  const registration = setupSteps(inspection, Fixture.sdkVersion)[3]!;

  // Then
  assert.match(registration.instructions, /Edit the file with the app's existing `@main` `App` struct/);
  assert.match(registration.instructions, /Add the three marked lines: `import AnyChatUI`/);
  for (const line of ["import AnyChatUI  // Add", "@State private var backend = InMemoryChatBackend()  // Add", ".chatBackend(backend)  // Add"]) {
    assert.ok(registration.instructions.includes(line), line);
  }
});

test("registering the backend stops a UIKit-lifecycle app instead of adding a SwiftUI App", () => {
  // Given
  const inspection = Fixture.inspection({ registersBackend: false });

  // When
  const registration = setupSteps(inspection, Fixture.sdkVersion)[3]!;

  // Then
  assert.match(registration.instructions, /If the app starts from a UIKit `AppDelegate` or `SceneDelegate` and has no SwiftUI `App`, do not add one/);
  assert.match(registration.instructions, /Stop and tell the user that this setup does not support UIKit-lifecycle apps\./);
});

test("an Xcode project is first asked whether to add a chat UI test", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ dependsOnSDK: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, undefined);

  // Then
  assert.match(text, /^1\. \[todo\] Ask whether to add a chat UI test$/m);
  assert.match(text, /## Next step: 1\. Ask whether to add a chat UI test/);
  assert.match(text, /call get_started again with `uiTests` set to their answer/);
  assert.match(text, /Do this step only, then call get_started again to check it/);
});

test("an answer of no adds no UI test steps and is passed on with each call", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ dependsOnSDK: false, hasUITestTarget: false, hasChatUITest: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, false);

  // Then
  assert.match(text, /^1\. \[done\] Ask whether to add a chat UI test$/m);
  assert.match(text, /## Next step: 3\. Add the AnyChatUI package/);
  assert.doesNotMatch(text, /UI test target|Add a chat UI test/);
  assert.match(text, /call get_started again with `uiTests: false`/);
});

test("an answer of yes adds the UI test target and the test after the entry point", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ hasUITestTarget: false, hasChatUITest: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, true);

  // Then
  assert.match(text, /^7\. \[done\] Add a chat entry point\n8\. \[todo\] Add a UI test target\n9\. \[todo\] Add a chat UI test$/m);
  assert.match(text, /## Next step: 8\. Add a UI test target/);
  assert.match(text, /Ask the user to add one in Xcode: File > New > Target…, choose UI Testing Bundle/);
  assert.match(text, /call get_started again with `uiTests: true`/);
});

test("a generated project adds the UI test target to its spec after the user confirms", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ generatorSpec: "project.yml", hasUITestTarget: false, hasChatUITest: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, true);

  // Then
  assert.match(text, /First ask the user to confirm that the project is still generated from `project\.yml`/);
  assert.match(text, /add a UI testing bundle target that tests the app to `project\.yml`/);
});

test("the chat UI test opens chat, enters the in-memory backend's channel, and sends a message", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ hasChatUITest: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, true);

  // Then
  assert.match(text, /## Next step: 9\. Add a chat UI test/);
  assert.match(text, /Add this file to the UI test target as `ChatUITests\.swift`/);
  for (const line of ['app.buttons["Chat"].firstMatch.tap()', 'private let channelName = "Welcome"', 'app.buttons["Send"].tap()']) {
    assert.ok(text.includes(line), line);
  }
  assert.match(text, /do not delete or skip the test/);
});

test("a project that lists its files gets the chat UI test pasted into an existing test file", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ compilesNewFiles: false, hasChatUITest: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, true);

  // Then
  assert.match(text, /Paste this code at the end of a Swift file that is already in the UI test target/);
  assert.doesNotMatch(text, /Add this file to the UI test target/);
});

test("a Swift package is not asked about UI tests", () => {
  // Given
  const result = { found: true as const, inspection: Fixture.inspection({ kind: "swiftPackage", dependsOnSDK: false }) };

  // When
  const text = renderGetStarted(result, "/App", Fixture.sdkVersion, undefined);

  // Then
  assert.doesNotMatch(text, /UI test/);
  assert.match(text, /## Next step: 2\. Add the AnyChatUI package/);
});
