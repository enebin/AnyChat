import type { AddPackageResult } from "./packageLink.js";
import { compareVersions, productName, type InspectionResult, type ProjectInspection } from "./project.js";

export const repositoryURL = "https://github.com/enebin/AnyChat";
const packageIdentity = "anychat";
const minimumIOSVersion = "18.0";

export type StepStatus = "done" | "todo" | "unknown";

export interface SetupStep {
  title: string;
  status: StepStatus;
  /** What to do while the step is not done. */
  instructions: string;
}

export function setupSteps(inspection: ProjectInspection, sdkVersion: string): SetupStep[] {
  const chatScreen = inspection.channelListScreen ?? "ChatScreen";
  const withChatScreen = (source: string) => source.replace(/\bChatScreen\b/g, chatScreen);
  const screenToOpen = inspection.channelListScreen
    ? `\`${chatScreen}()\``
    : "`ChatScreen()`, or the view that shows `ChannelListView` if it has another name,";
  return [
    deploymentTargetStep(inspection),
    dependencyStep(inspection, sdkVersion),
    {
      title: "Add an in-memory backend",
      status: inspection.implementsBackend ? "done" : "todo",
      instructions: [
        newSourceFile(inspection, "InMemoryChatBackend.swift"),
        "It lets the channel list and channel screens run with no account or network. Messages last as long as their channel screen is open. A real backend adapter replaces it later.",
        swift(inMemoryBackendSource),
      ].join("\n\n"),
    },
    {
      title: "Register the backend at the app root",
      status: inspection.registersBackend ? "done" : "todo",
      instructions: [
        "Edit the file with the app's existing `@main` `App` struct; keep its name and its root view. Add the three marked lines: `import AnyChatUI` if the file does not import it yet (Xcode 26 projects do not see another module's modifiers without it), the backend in `@State` so it outlives view updates, and the backend registered once on the root view inside `WindowGroup`, whatever that view is called. Change nothing else in the file.",
        swift(registrationSource),
        "This setup supports apps that start from a SwiftUI `App`. If the app starts from a UIKit `AppDelegate` or `SceneDelegate` and has no SwiftUI `App`, do not add one and do not change the app's entry point. Stop and tell the user that this setup does not support UIKit-lifecycle apps.",
      ].join("\n\n"),
    },
    {
      title: "Add the chat screen",
      status: inspection.placesChannelList ? "done" : "todo",
      instructions: [
        newSourceFile(inspection, "ChatScreen.swift"),
        "It shows the channel list in its own `NavigationStack` and pushes the channel screen when a channel is selected. Do not change the app's existing screens; the next step opens this one from them. If the app already declares a type named `ChatScreen`, give this one a name the app does not use yet and name its file after it instead of `ChatScreen.swift`. The next step finds the screen by the channel list it shows, whatever its name.",
        swift(chatScreenSource),
        "To change how the list or the channel screen looks or behaves, call list_components and describe_component after setup.",
      ].join("\n\n"),
    },
    {
      title: "Add a chat entry point",
      status: inspection.opensChannelList ? "done" : "todo",
      instructions: [
        `Open ${screenToOpen} from the app's existing UI without removing anything. Read the app's views and choose one:`,
        "- **The app has a `TabView`:** add a Chat tab to it. If its tabs are written with `Tab(...)`, add:",
        swift(withChatScreen(chatTabSource)),
        "  If its tabs use `.tabItem`, add a child with the same style instead:",
        swift(withChatScreen(chatTabItemSource)),
        "  If the `TabView` takes a `selection:`, give the Chat tab a value the same way the other tabs have one: `value:` for `Tab` (`Tab(\"Chat\", systemImage: \"bubble.left.and.bubble.right\", value: ...)`), `.tag(_:)` for `.tabItem`. Use a value of the selection's type that no other tab uses, adding a case if the selection is an enum.",
        `- **Otherwise, the app's main screen is inside a \`NavigationStack\`:** add a toolbar button that presents \`${chatScreen}\` as a sheet. Put the \`@State\` property in the view that holds that \`NavigationStack\`, and the two modifiers on the view inside the \`NavigationStack\`, not on the \`NavigationStack\` itself:`,
        swift(withChatScreen(chatSheetSource)),
        "- **Neither fits clearly** (several candidate screens, or no `TabView` and no `NavigationStack`): ask the user once where chat should open, then do that.",
      ].join("\n\n"),
    },
  ];
}

function uiTestQuestionStep(uiTests: boolean | undefined): SetupStep {
  return {
    title: "Ask whether to add a chat UI test",
    status: uiTests === undefined ? "todo" : "done",
    instructions: [
      "Before changing anything, ask the user once: \"Should I also add a UI test that opens chat, enters a channel, and sends a message?\"",
      "Then call get_started again with `uiTests` set to their answer, `true` or `false`, and pass the same `uiTests` on every later call. If they answer no, add no test.",
    ].join("\n\n"),
  };
}

function uiTestSteps(inspection: ProjectInspection): SetupStep[] {
  return [
    {
      title: "Add a UI test target",
      status: inspection.hasUITestTarget ? "done" : "todo",
      instructions: inspection.generatorSpec === undefined
        ? "The project has no UI test target. Adding a target adds objects to `project.pbxproj`, so do not do it by hand. Ask the user to add one in Xcode: File > New > Target…, choose UI Testing Bundle, and set Target to be Tested to the app. Then call get_started again."
        : `The project has no UI test target. First ask the user to confirm that the project is still generated from \`${inspection.generatorSpec}\`. If it is, add a UI testing bundle target that tests the app to \`${inspection.generatorSpec}\` the way it declares its other targets, then regenerate the project. If it is not, ask the user to add one in Xcode: File > New > Target…, choose UI Testing Bundle, and set Target to be Tested to the app.`,
    },
    {
      title: "Add a chat UI test",
      status: inspection.hasChatUITest ? "done" : "todo",
      instructions: [
        inspection.compilesNewFiles
          ? "Add this file to the UI test target as `ChatUITests.swift`, in the folder Xcode made for that target."
          : "This project lists each source file in `project.pbxproj`, so a new file would not be compiled. Do not create a file and do not add one to `project.pbxproj`. Paste this code at the end of a Swift file that is already in the UI test target, such as the `UITests.swift` file Xcode made with it, merging the `import` lines.",
        "It opens chat by tapping the button labeled Chat, which is both the Chat tab and the Chat toolbar button the entry point step adds. If chat opens some other way in this app, change that tap to match. It then opens the in-memory backend's Welcome channel and sends a message. When a real backend replaces the in-memory one, change the channel name to one that backend has.",
        swift(chatUITestSource),
        "Then run the test with Product > Test in Xcode or with `xcodebuild test`, choosing an available iPhone simulator. If it fails, fix the cause in the app or the test; do not delete or skip the test.",
      ].join("\n\n"),
    },
  ];
}

function newSourceFile(inspection: ProjectInspection, fileName: string): string {
  return inspection.compilesNewFiles
    ? `Add this file to the app target as \`${fileName}\`.`
    : "This project lists each source file in `project.pbxproj`, so a new file would not be compiled. Do not create a file and do not add one to `project.pbxproj`. Paste this code at the end of a Swift file that is already in the app target, such as the file with `@main`, merging the `import` lines.";
}

function deploymentTargetStep(inspection: ProjectInspection): SetupStep {
  const title = `Target iOS ${minimumIOSVersion} or later`;
  const target = inspection.iosDeploymentTarget;
  const instructions = inspection.kind === "xcodeProject"
    ? `In \`project.pbxproj\`, raise every \`IPHONEOS_DEPLOYMENT_TARGET\` below \`${minimumIOSVersion}\` to \`${minimumIOSVersion}\`, including the project-level settings and every target's. Edit only these values; changing a build setting's value is safe by hand, unlike adding objects to the file.`
    : `Declare \`platforms: [.iOS(.v18)]\` or later in \`Package.swift\`.`;

  if (target === undefined) {
    return { title, status: "unknown", instructions: `No iOS deployment target was found. ${instructions}` };
  }
  if (compareVersions(target, minimumIOSVersion) < 0) {
    return { title, status: "todo", instructions: `The project targets iOS ${target}. ${instructions}` };
  }
  return { title, status: "done", instructions };
}

function dependencyStep(inspection: ProjectInspection, sdkVersion: string): SetupStep {
  const title = `Add the ${productName} package`;
  const status = inspection.dependsOnSDK ? "done" : "todo";

  if (inspection.kind === "xcodeProject" && inspection.generatorSpec === "project.yml") {
    return {
      title,
      status,
      instructions: [
        confirmGenerated("project.yml", sdkVersion),
        "This project is generated by XcodeGen, so `project.pbxproj` is overwritten on every `xcodegen generate`. Add the package to `project.yml` instead, then run `xcodegen generate`:",
        yaml(`packages:\n  ${packageIdentity}:\n    url: ${repositoryURL}\n    from: ${sdkVersion}\ntargets:\n  <app target>:\n    dependencies:\n      - package: ${packageIdentity}\n        product: ${productName}`),
      ].join("\n\n"),
    };
  }
  if (inspection.kind === "xcodeProject" && inspection.generatorSpec !== undefined) {
    return {
      title,
      status,
      instructions: `${confirmGenerated(inspection.generatorSpec, sdkVersion)}\n\nThis project is generated by Tuist from \`${inspection.generatorSpec}\`, so \`project.pbxproj\` is overwritten on every \`tuist generate\`. Add \`${repositoryURL}\`, from \`${sdkVersion}\`, and the \`${productName}\` product to the app target the way the project's Tuist manifests declare their other packages, then run \`tuist generate\`.`,
    };
  }
  if (inspection.kind === "xcodeProject") {
    return {
      title,
      status,
      instructions: `Call the add_package tool with projectPath \`${inspection.projectPath}\`. The project can stay open in Xcode. Do not edit \`project.pbxproj\` by hand to add it. If the tool lists several targets, ask the user which one shows the chat UI and call it again with targetName.`,
    };
  }

  return {
    title,
    status,
    instructions: [
      "Add the package to `dependencies` in `Package.swift`:",
      swift(`.package(url: "${repositoryURL}", from: "${sdkVersion}")`),
      "Then add the product to the target that shows the chat UI:",
      swift(`.product(name: "${productName}", package: "${packageIdentity}")`),
    ].join("\n\n"),
  };
}

/** A Swift package has no app to launch, so UI tests are offered only for an Xcode project. */
function allSteps(inspection: ProjectInspection, sdkVersion: string, uiTests: boolean | undefined): SetupStep[] {
  const steps = setupSteps(inspection, sdkVersion);
  if (inspection.kind !== "xcodeProject") {
    return steps;
  }
  return [uiTestQuestionStep(uiTests), ...steps, ...(uiTests ? uiTestSteps(inspection) : [])];
}

export function renderGetStarted(
  result: InspectionResult,
  searchedPath: string,
  sdkVersion: string,
  uiTests: boolean | undefined,
): string {
  if (!result.found) {
    return result.candidates.length === 0
      ? `No \`.xcodeproj\` or \`Package.swift\` was found in \`${searchedPath}\`. Call get_started again with the directory of the user's iOS app.`
      : [
          `More than one project was found in \`${searchedPath}\`. Ask the user which one is the app, then call get_started again with that path:`,
          result.candidates.map((candidate) => `- \`${candidate}\``).join("\n"),
        ].join("\n\n");
  }

  const steps = allSteps(result.inspection, sdkVersion, uiTests);
  const next = steps.findIndex((step) => step.status !== "done");
  const lines = [
    `# ${productName} ${sdkVersion} setup`,
    `Project: \`${result.inspection.projectPath}\``,
    steps.map((step, index) => `${index + 1}. [${step.status}] ${step.title}`).join("\n"),
  ];

  if (next === -1) {
    lines.push("Every step is done. Build and run the app: the chat entry point opens the channel list with the channels from the registered backend. The default UI uses Apple system colors, SF Symbols, and Dynamic Type, with blue outgoing bubbles and gray incoming bubbles. To customize the chat UI, call list_components, then describe_component with a component's name.");
  } else {
    lines.push(`## Next step: ${next + 1}. ${steps[next]!.title}`, steps[next]!.instructions);
    lines.push(
      uiTests === undefined
        ? "Do this step only, then call get_started again to check it and get the next one."
        : `Do this step only, then call get_started again with \`uiTests: ${uiTests}\` to check it and get the next one.`,
    );
  }
  return lines.join("\n\n");
}

export function renderAddPackage(result: AddPackageResult, xcodeprojPath: string, sdkVersion: string): string {
  switch (result.status) {
    case "linked":
      return [
        `Linked the \`${productName}\` product into the \`${result.targetName}\` target of \`${xcodeprojPath}\`.`,
        result.reusedReference ? "The project already referenced the package, so only the product was added." : "",
        "If Xcode has the project open and asks about the change on disk, the user must choose the version on disk; keeping Xcode's version writes the project back without the package. Call get_started again for the next step.",
      ].filter(Boolean).join(" ");
    case "alreadyLinked":
      return `The \`${result.targetName}\` target already links \`${productName}\`. Nothing changed. Call get_started again for the next step.`;
    case "chooseTarget":
      return [
        result.candidates.length === 0
          ? "The project has no targets to link the package into."
          : "Ask the user which target shows the chat UI, then call add_package again with that targetName:",
        result.candidates.map((candidate) => `- \`${candidate}\``).join("\n"),
      ].filter(Boolean).join("\n\n");
    case "notFound":
      return `No \`project.pbxproj\` was found in \`${xcodeprojPath}\`. Pass the absolute path of the app's \`.xcodeproj\`.`;
    case "generated":
      return [
        `\`${xcodeprojPath}\` looks generated from \`${result.specFile}\`, so editing \`project.pbxproj\` would be lost on the next generation. Nothing changed.`,
        confirmGenerated(result.specFile, sdkVersion),
        `If it is generated, call get_started for how to add the package to \`${result.specFile}\`.`,
      ].join(" ");
    case "invalid":
      return `Nothing changed: the rewritten project failed its check (${result.reason}). Ask the user to add the package in Xcode with File > Add Package Dependencies.`;
  }
}

// The spec is detected by file name alone, and regenerating a project that is no longer generated replaces
// its hand-edited project file, so the user confirms before the agent runs the generator.
function confirmGenerated(specFile: string, sdkVersion: string): string {
  const command = specFile === "project.yml" ? "xcodegen generate" : "tuist generate";
  return `First ask the user to confirm that the project is still generated from \`${specFile}\`: running \`${command}\` on a project that is no longer generated replaces its hand-edited \`project.pbxproj\`. If it is not generated, ask the user to add the package in Xcode instead: File > Add Package Dependencies…, enter \`${repositoryURL}\`, choose Up to Next Major Version from \`${sdkVersion}\`, and add the \`${productName}\` product to the app target.`;
}

function swift(source: string): string {
  return "```swift\n" + source + "\n```";
}

function yaml(source: string): string {
  return "```yaml\n" + source + "\n```";
}

const inMemoryBackendSource = `import Foundation
import AnyChatUI

@MainActor
final class InMemoryChatBackend: ChatBackend {
    static let userID = "me"

    let currentUserID: String? = InMemoryChatBackend.userID

    func makeChannelListRepository() -> any ChannelListRepository {
        InMemoryChannelListRepository()
    }

    func makeChannelRepository(channelID: String) -> any ChannelRepository {
        InMemoryChannelRepository()
    }
}

@MainActor
final class InMemoryChannelListRepository: ChannelListRepository {
    private var channels = [
        ChatChannel(id: "welcome", name: "Welcome", createdAt: Date(), notificationLevel: .all, canLeave: true),
        ChatChannel(id: "general", name: "General", createdAt: Date(), notificationLevel: .all, canLeave: true)
    ]
    private var continuation: AsyncStream<[ChatChannel]>.Continuation?

    func startObserving() -> AsyncStream<[ChatChannel]> {
        stopObserving()
        let (stream, continuation) = AsyncStream<[ChatChannel]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        return stream
    }

    func loadMore() async throws -> ChannelListPage {
        guard continuation != nil else {
            throw ChannelListRepositoryError.notObserving
        }
        return ChannelListPage(channels: channels, hasNext: false)
    }

    func leave(channelID: String) async throws {
        channels.remove(at: try index(of: channelID))
        continuation?.yield(channels)
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {
        channels[try index(of: channelID)].notificationLevel = level
        continuation?.yield(channels)
    }

    func stopObserving() {
        continuation?.finish()
        continuation = nil
    }

    private func index(of channelID: String) throws -> Int {
        guard let index = channels.firstIndex(where: { $0.id == channelID }) else {
            throw ChannelListRepositoryError.channelNotFound
        }
        return index
    }
}

@MainActor
final class InMemoryChannelRepository: ChannelRepository {
    private let sender = ChatSender(id: InMemoryChatBackend.userID)
    private var messages: [ChatMessage] = []
    private var continuation: AsyncStream<[ChatMessage]>.Continuation?

    func startObserving() -> AsyncStream<[ChatMessage]> {
        stopObserving()
        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        return stream
    }

    func loadPrevious() async throws -> MessagePage {
        guard let continuation else {
            throw ChannelRepositoryError.notObserving
        }
        continuation.yield(messages)
        return MessagePage(messages: messages, hasPrevious: false)
    }

    func sendMessage(text: String, replyTo: String?) {
        append(ChatMessage(id: UUID().uuidString, sender: sender, createdAt: Date(), text: text, attachments: []))
    }

    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        let id = UUID().uuidString
        let sent = attachments.enumerated().map { index, attachment in
            ChatAttachment(id: "\\(id)-\\(index)", kind: attachment.kind, url: attachment.fileURL, fileName: attachment.fileName)
        }
        append(ChatMessage(id: id, sender: sender, createdAt: Date(), attachments: sent))
    }

    func resendMessage(id: String) {}

    func removeFailedMessage(id: String) {}

    func stopObserving() {
        continuation?.finish()
        continuation = nil
    }

    private func append(_ message: ChatMessage) {
        messages.append(message)
        continuation?.yield(messages)
    }
}`;

const registrationSource = `import SwiftUI
import AnyChatUI  // Add

@main
struct MyApp: App {  // The app's existing App struct, under its own name
    @State private var backend = InMemoryChatBackend()  // Add

    var body: some Scene {
        WindowGroup {
            ContentView()  // The app's existing root view, unchanged
                .chatBackend(backend)  // Add
        }
    }
}`;

const chatScreenSource = `import SwiftUI
import AnyChatUI

struct ChatScreen: View {
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        NavigationStack {
            ChannelListView()
                .onChannelSelected { channel in
                    selectedChannel = channel
                }
                .navigationDestination(item: $selectedChannel) { channel in
                    ChannelView(channel: channel)
                }
        }
    }
}`;

const chatUITestSource = `import XCTest

nonisolated final class ChatUITests: XCTestCase {
    private let timeout: TimeInterval = 10
    private let channelName = "Welcome"
    private let sentText = "Hello from the UI test"

    @MainActor
    func testChatOpensAChannelAndSendsAMessage() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        app.buttons["Chat"].firstMatch.tap()
        let channel = app.staticTexts[channelName]
        XCTAssertTrue(channel.waitForExistence(timeout: timeout))
        channel.tap()

        // The composer is a text field or a text view depending on the iOS version.
        let fieldTypes = [XCUIElement.ElementType.textField, .textView].map(\\.rawValue)
        let field = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND elementType IN %@", "Message", fieldTypes))
            .firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText(sentText)
        app.buttons["Send"].tap()

        XCTAssertTrue(app.staticTexts[sentText].waitForExistence(timeout: timeout))
    }
}`;

const chatTabSource = `Tab("Chat", systemImage: "bubble.left.and.bubble.right") {
    ChatScreen()
}`;

const chatTabItemSource = `ChatScreen()
    .tabItem {
        Label("Chat", systemImage: "bubble.left.and.bubble.right")
    }`;

const chatSheetSource = `@State private var showsChat = false

// On the view inside the NavigationStack:
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Chat", systemImage: "bubble.left.and.bubble.right") {
            showsChat = true
        }
    }
}
.sheet(isPresented: $showsChat) {
    ChatScreen()
}`;
