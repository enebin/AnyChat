# MCP server

A sub-document of [ARCHITECTURE.md](../../ARCHITECTURE.md) section 11. It defines what the MCP server in `MCP/` does, how it splits work with the customer's coding agent, and how its guidance stays in step with the SDK.

The server is the entry point customers install instead of the SDK. Their coding agent follows it from the tutorial through setup, UI customization, and backend connection with no manual step ([AGENTS.md](../../AGENTS.md) product direction 2).

## Division of work

- **The customer's agent writes the customer's source code.** It already has tools to edit files. The MCP server is not a code generator.
- **The server says what to do and where, and checks whether it was done right.** Checking is what makes it more than documentation; a tool that only returns fixed text is no better than a document.
- **The server edits only project settings files that are risky for an agent to edit by hand.** For example, adding an SPM dependency to an `.xcodeproj`'s `project.pbxproj`.
- **In `project.pbxproj`, changing an existing build-setting value is the agent's job; adding objects is not.** Raising `IPHONEOS_DEPLOYMENT_TARGET` is a value edit. Adding a package, a file, or a target is the server's job, or the user's in Xcode until a tool exists.

| Flow | What the server does |
|---|---|
| Tutorial | Reads the customer's project (Xcode project or SPM, iOS version) and returns the steps |
| Setup | Adds the package dependency and guides the `.chatBackend(_:)` registration and where the first screen goes |
| UI customization | Describes each component (initializers, slots, callbacks, theme, options) with each symbol's doc comment, through the component catalog, and hands over the Showcase demos that combine them |
| Backend connection | Returns the boundary protocols and the [adapter rules](backend-boundary.md#어댑터-규약), and checks whether the customer's adapter follows them |

Today there are five tools: `get_started` covers the tutorial and setup, `add_package` adds the package to an `.xcodeproj`, and `list_components`, `describe_component`, and `show_demo` read the component catalog for UI customization. Other tools are named when they are built.

## `get_started`

Reads the customer's project, marks each setup step `done`, `todo`, or `unknown`, and returns the instructions for the first unfinished step only. The agent does that one step and calls again; calling again is the check.

| Step | When it is `done` |
|---|---|
| Ask whether to add a chat UI test | `get_started` received `uiTests`. Only for an Xcode project |
| iOS 18.0 or later | The lowest `IPHONEOS_DEPLOYMENT_TARGET` anywhere in `project.pbxproj` (project level and every target), or the lowest `.iOS(...)` in `Package.swift` |
| Add the package | `productName = AnyChatUI;` in `project.pbxproj`, or `"AnyChatUI"` in `Package.swift` |
| Add an in-memory backend | A type declaration or extension in the app's Swift sources adopts `ChatBackend`, in a file the project compiles |
| Register the backend | The app's Swift sources contain `.chatBackend(` |
| Add the chat screen | A file the project compiles uses `ChannelListView(`, outside `#Preview` blocks, comments, and string literals |
| Add a chat entry point | A type that uses `ChannelListView(` is the app's `App`, or a file the project compiles contains `Name(` for it outside that type's declarations, `#Preview` blocks, comments, and string literals |
| Add a UI test target | Only with `uiTests: true`. `project.pbxproj` has a `com.apple.product-type.bundle.ui-testing` target |
| Add a chat UI test | Only with `uiTests: true`. A file the project compiles contains `XCUIApplication` and `buttons["Send"]` |

- **The user decides on a chat UI test before setup starts.** The first step asks the agent to put the question to the user once, then pass the answer as `uiTests` on every later call; the server keeps no state between calls. With `true`, two steps follow the entry point. A missing UI test target is added by the user in Xcode (File > New > Target > UI Testing Bundle), because adding a target adds objects to `project.pbxproj`; a generated project adds it to its spec after the user confirms it is still generated. The test then opens chat through the button labeled Chat (the Chat tab or the Chat toolbar button), opens the in-memory backend's `Welcome` channel, sends a message, and checks that it appears. It is checked to pass on iOS 18.4 and 26.4 with either entry point, and to compile with no warnings under Swift 6 with `MainActor` default isolation, which is why the class is `nonisolated`. A Swift package has no app to launch, so it is not asked.
- The checks are text matches. They do not build the project. The first goal is never to get "what to do next" wrong.
- **The chat steps look for the channel list, not for the name `ChatScreen`.** An app may already have its own `ChatScreen` (say, a support page), which must not count as chat; the chat screen step then tells the agent to give the new screen another name. The entry point step names the screen to open: the first type the app declares whose body uses `ChannelListView`, so an agent that resumes at that step need not know the name. A use in an extension of a type the app does not declare, such as an `extension View` helper, names no screen, and the step falls back to `ChatScreen` or the view that shows `ChannelListView`. An app may also have placed `ChannelListView` in a view of its own (say, an `InboxView` tab), which must not get a second chat screen and entry point.
- **Setup adds to an app that already has screens and never replaces its files.** Registering the backend edits the existing `@main` `App`: `import AnyChatUI` when the file lacks it, a `@State` property, and `.chatBackend(_:)` on the existing root view. The chat screen is a new ready-made `ChatScreen` (a `NavigationStack` with `ChannelListView` that pushes `ChannelView`). The entry point is chosen by the agent from the app's structure: an existing `TabView` gets a Chat tab (in the `Tab` or `.tabItem` style the app already uses, with a `value:` or `.tag(_:)` when the `TabView` takes a `selection:`); otherwise a toolbar button inside the main `NavigationStack` presents `ChatScreen` as a sheet; when neither fits clearly, the agent asks the user once. The entry point check skips the screen's own declarations because a project that lists each file pastes the chat screen into an existing file, which may hold the entry point too.
- **Setup supports apps that start from a SwiftUI `App`.** A UIKit-lifecycle app (`AppDelegate` / `SceneDelegate`, showing SwiftUI through `UIHostingController`) is not supported: registering the backend tells the agent to stop and tell the user rather than add a second `@main` or replace the entry point. Supporting it would need its own branches in the backend and entry point steps, because each `UIHostingController` is a separate SwiftUI tree that needs its own `.chatBackend(_:)`.
- A project from before Xcode 16 lists every source file in `project.pbxproj` (no `PBXFileSystemSynchronizedRootGroup`), so a new file on disk is not compiled. For such a project the backend and chat screen steps ask the agent to paste the code into a file already in the app target, and the checks count the backend and the chat screen only in a file named in `project.pbxproj`.
- When several projects are found, the tool does not pick one. It returns the candidates and the agent asks the user.
- For an `.xcodeproj`, the package step tells the agent to call `add_package` and never to hand-edit `project.pbxproj` for this. A project generated by XcodeGen (`project.yml`) or Tuist (`Project.swift`) is told to add the package to that spec and regenerate, because regeneration overwrites `project.pbxproj`.
- Build output and dependency checkouts (`.build`, `DerivedData`, `Pods`, and the like) are not read, so the SDK's own sample code is never mistaken for the customer's.
- The in-memory backend in the tutorial implements every repository `ChatBackend` makes, so it changes whenever `ChatBackend` does (see "Keeping the MCP in step with the SDK").

## `add_package`

`add_package({ projectPath, targetName?, packagePath? })` links the `AnyChatUI` product into one target of an `.xcodeproj`.

- **Which target.** With no `targetName`, the single app target (`com.apple.product-type.application`). With several app targets, or a name that matches nothing, it changes nothing and returns the candidates; the agent asks the user.
- **Which package.** By default the repository URL with "up to next major version, from" the server's own version. With `packagePath`, a local checkout, referenced by its path relative to the project. The local form exists to try an unreleased version; the remote form is the customer's path.
- **What it writes.** Up to six places in `project.pbxproj`: the package reference (`XCRemoteSwiftPackageReference` or `XCLocalSwiftPackageReference`), the project's `packageReferences`, an `XCSwiftPackageProductDependency`, the target's `packageProductDependencies`, a `PBXBuildFile`, and the target's Frameworks phase, which it creates when the target has none. An existing reference to the same package is reused. Otherwise the edit only adds lines, with one exception: the writer drops leading zeros from integers, so an older project's `LastUpgradeCheck = 0800;` becomes `800;`. Xcode reads both as the same number.
- **Idempotent.** When the target already depends on the product, it changes nothing and says so.
- **Generated projects are refused.** With `project.yml` or `Project.swift` next to the `.xcodeproj`, it changes nothing. The spec is detected by file name alone, and regenerating a project that is no longer generated would replace its hand-edited `project.pbxproj`. So both `add_package` and the package step tell the agent to confirm with the user before running the generator, and give the Xcode menu steps for a project that turns out not to be generated.
- **The project can stay open in Xcode.** Checked in Xcode 26.4: with no unsaved changes, Xcode reloads the edited file silently and shows the package. Only unsaved changes at that moment could make Xcode ask which version to keep, so the `linked` result tells the user to choose the version on disk.
- **Write, check, then replace.** The new text goes to a temporary file next to the original. `plutil -lint` checks its syntax, and the file is parsed again to confirm the target now depends on the product. Only then does it replace the original, so a failure leaves the project untouched.

Two choices behind it:

- **The parser is the `xcode` npm package.** Parsing and writing back unchanged reproduced five real projects byte for byte (Xcode 26 synchronized, XcodeGen, older formats); none of them had leading-zero integers. `@bacons/xcode` rewrote up to 270 lines of an unchanged XcodeGen project. Inserting text by hand would also have to create missing sections and phases as strings.
- **The check is not `xcodebuild -list`.** It resolves packages even with `-disableAutomaticPackageResolution`, so it fails on a correct edit whenever the package cannot be fetched: offline, or before a release tag exists. `plutil -lint` and the re-parse run offline.

## Component catalog

Agents should be able to work with one part of the SDK at a time, such as "put the channel screen in our detail page" or "change how a channel row looks", not only through the setup walk. The catalog describes the SDK component by component. `list_components` and `describe_component` read it, and `show_demo` returns the demos that show components in use. The tools stay the same as components and demos are added; only the data grows. There is no tool per component or per demo.

### What a component is

A component is one public `View` type in `AnyChatUI` together with everything that customizes it. Today there are two: `ChannelListView` and `ChannelView`. Membership follows the repository's naming rule for screen types (`ChannelListView` / `ChannelListTheme` / `ChannelListOptions`):

| Part | Where it comes from | Example |
|---|---|---|
| Initializers | The view's public initializers | `ChannelView(channel:)`, `ChannelView(channel:repository:currentUserID:)` |
| Slots | Modifiers in a public extension of the view that take a view-building closure | `channelRow`, `messageContent` |
| Callbacks | Modifiers whose names start with `on` | `onChannelSelected`, `onAttachmentSelected` |
| Settings | The extension's other modifiers | `navigationTitleText` |
| Theme | The public `<Screen>Theme` type with its members, and the `View.<screen>Theme(_:)` modifier that applies it | `ChannelListTheme`, its `unreadBadgeBackground`, `.light`, `channelListTheme(_:)` |
| Options | The public `<Screen>Options` type with its members, when there is one | `ChannelListOptions`, its `isTypingIndicatorEnabled` |
| Context values | Public value types of `AnyChatUI` that slots receive, with their members | `MessageRowContext`, its `isMine` |

Every part carries its signature and its `///` comment as written in the source. **Every type the catalog describes carries all of its public members**: properties, enum cases, initializers, static members such as theme presets, methods, and nested types, each with signature and doc comment. An agent asked to "make the unread badge red" needs the property's name, and one switching on `message.content` needs the cases, not only the type's name.

- **What a component needs before it can appear is stated in the view's own doc comment**, such as a backend registered with `.chatBackend(_:)` above it, or an `Info.plist` key for the camera. The catalog has no separate requirements field, so the source has one place for it.
- **The types a component's signatures use are described with it.** Agents writing a slot read the values it receives, such as a channel's `unreadMessageCount`, so they need each type's members, not just its name. These are the public types of `AnyChatCore` (`ChatChannel`, `ChatMessage`, ...) reachable from the component's initializers, slots, and callbacks, following the types their public members use. The walk stops at the backend boundary: every `AnyChatCore` protocol it reaches, such as the repository protocols that the overriding initializers take (`ChannelRepository`, `ChannelListRepository`), is named only, so the UI catalog stays about UI and the adapter contract stays in the [adapter rules](backend-boundary.md#어댑터-규약). In their place, `describe_component` points to registering a backend through `.chatBackend(_:)`, which `get_started` sets up. They come from the same symbol graph. Domain models are not components themselves; `list_components` does not list them.

### Demos

The Showcase app (`Examples/QuickStart/Showcase`, [ARCHITECTURE.md](../../ARCHITECTURE.md) section 9) holds demos built from public API only: themes, slots, streaming text, channel updates, and an agent transcript made from custom content and a typed row slot. A component entry lists its parts one by one; a demo shows several parts working together. So demos are the reference for a request such as "build an agent-style chat screen", which no single slot answers.

- **A demo is one folder, `Showcase/<Name>/`.** It holds `<Name>Demo.swift` with the `<Name>Demo` view, and every other Showcase file the demo uses. For example, `Showcase/Agent/` holds `AgentDemo.swift` and `AgentChannelRepository.swift`. Its name is `<Name>`. Membership is the folder, not a file-name prefix, so one demo never picks up another's files.
- **Demos share no Showcase file.** A small helper that two demos need is repeated in each as a `private` declaration, so every shipped demo is complete on its own and never uses a declaration the agent cannot see, such as an extension on an SDK type. The only file at the root of `Showcase/` is the app's demo list, which is not shipped.
- **Its description is the first sentence of the `///` comment on the `<Name>Demo` view**, ending at the first period followed by a space, or at the end of the comment. Attribute lines such as `@MainActor` between the comment and the view are skipped. A demo view without the comment fails the pack.
- **The components it shows are the component views whose names appear in its files**, such as `ChannelView`.
- None of these is written by hand, so a new demo needs nothing in `MCP/`.
- **A demo is a reference to read, not a file to paste.** Outside its folder, a demo uses only the sample backend and sample values in `Examples/QuickStart/Shared`, which are not shipped. Every name declared there starts with `Sample` (`SampleChatBackend`, `SampleData`, `SamplePoll`), so the agent can tell which names to replace with the app's own. The placement example is the code meant to be pasted.

### `list_components`

No input. It returns every component with the first sentence of its doc comment, and says to call `describe_component` for one of them.

### `describe_component({ name })`

It returns one component's catalog entry, in this order:

1. its doc comment, which states what it needs before it can appear
2. its initializers, slots, callbacks, settings, theme, options, and context values, each with signature and doc comment, and each type with all of its public members
3. the domain types those signatures use, each with all of its public members
4. the backend boundary protocols by name, with a pointer to registering a backend through `.chatBackend(_:)`
5. its placement example
6. the demos that show it, each with its description, and a pointer to `show_demo`

Each part with nothing in it is left out. Declarations are shown as a Swift interface: each doc comment as `///` lines above its declaration, each type's protocol conformances after its name, and each type's members inside its braces, nested types included. An agent reads the exact names and signatures the way it would read a generated Swift interface.

An unknown name is an error that lists the known names.

### `show_demo({ name })`

It returns one demo's files, each with its path and source. Before them it says that the demo is a reference, and that names starting with `Sample` come from the sample backend and are stand-ins the agent replaces with the app's own. When the demo registers a backend with `.chatBackend(_:)`, it adds that the demo does so only to stay separate from the other demos, and that the app keeps its single backend registered at its root. An unknown name changes nothing and returns the known demos with their descriptions.

### Where the data lives

- **Generated:** `MCP/catalog/components.json`. Components and the domain types they use; everything except the placement examples comes from the SDK's public symbol graph and is never edited by hand. It is checked in and shipped in the npm package, because customers run the server with npx and have no Swift build.
  - **Regenerate:** `npm run catalog` in `MCP/`. **Check:** `npm run catalog:check` fails when the file no longer matches the public API, such as after a doc comment changed without regenerating. Both need Xcode.
  - **How:** `MCP/scripts/generateCatalog.ts` runs `xcodebuild docbuild` on the package scheme into a temporary DerivedData and reads the `AnyChatCore` and `AnyChatUI` symbol graphs it emits; `MCP/scripts/catalog.ts` turns them into the catalog. iOS-only packages cannot use `swift build` ([ARCHITECTURE.md](../../ARCHITECTURE.md) section 8). `xcodebuild build` can emit symbol graphs too, but only by overriding `OTHER_SWIFT_FLAGS`, which can drop the package's own compiler settings; `docbuild` emits them without touching the build.
  - **How the parts are recognized:** a component is a public struct in `AnyChatUI` that conforms to `View`. Among its methods, one with a `View` in its signature is a slot, one whose name starts with `on` and a capital letter is a callback, and the rest are settings. The theme, options, and theme modifier are found by the naming rule above. Context values are the `AnyChatUI` types in slot and callback signatures. The walk for domain types treats every `AnyChatCore` protocol as the backend boundary. Declarations are the compiler's, so they spell out implicit attributes such as `@MainActor`. Members are listed in source order; documentation a member inherits from a standard library protocol is left out. A type's conformances come from its `conformsTo` relationships, sorted by name because the graph does not keep their source order; they include the ones a protocol implies, such as `Equatable` with `Hashable`, but not `SendableMetatype`, which the compiler adds to every `Sendable` type.
- **Hand-written:** one placement example per component, `MCP/catalog/examples/<Component>.swift`. It shows where the view goes in an app (inside a `NavigationStack`, pushed on selection, and so on). It is a real Swift file, and `npm run catalog:check` compiles every example in a temporary iOS package that depends on this checkout and fails on any error or warning (`MCP/scripts/buildExamples.ts`).
- **Copied when the package is packed:** the demos. `MCP/scripts/packDemos.ts`, run by `prepack` and before `npm test`, copies each demo folder `Examples/QuickStart/Showcase/<Name>/` into `MCP/demos/<Name>/`, with an `index.json` of names, descriptions, components, files, stand-ins, and whether the demo registers a backend, built by the rules in "Demos" (`MCP/scripts/demoIndex.ts`). The stand-ins are the top-level types of `Shared/` that a demo's files name. A server run from a checkout that has not run the script lists no demos. No copy is checked in under `MCP/`, so each demo lives in one place. The Showcase app is built by the verification commands ([AGENTS.md](../../AGENTS.md) "테스트 / 검증"), so a shipped demo compiles against the SDK of the same tag.

## Keeping the MCP in step with the SDK

Customers' agents write code only as the server tells them, so when the two disagree the customer's build breaks. A PR that changes any of the following updates the MCP side in the same PR ([AGENTS.md](../../AGENTS.md) "Public API 규율").

| When the PR changes | Update |
|---|---|
| A component is added, removed, or renamed, or its `Theme` / `Options` type is | Regenerate the catalog; add, remove, or rename its placement example |
| A public initializer, slot, callback, setting, theme or options property, context value, or their doc comments | Regenerate the catalog; fix the placement example if it uses the changed symbol |
| A public domain model (`AnyChatCore`) or its doc comments | Regenerate the catalog; fix the placement examples and the Swift snippets in `MCP/src/guide.ts` that use it, and compile them again |
| The backend boundary (`ChatBackend`, the repositories) | Fix the in-memory backend and the other Swift snippets in `MCP/src/guide.ts`, and compile them again |
| What a screen needs before it can appear | State it in the view's doc comment and regenerate the catalog; fix `get_started`'s steps and checks if setup must change |
| The setup order | Fix `get_started`'s steps and checks in `MCP/src/guide.ts` and `MCP/src/project.ts`, and the step table above |
| The composer's accessibility labels (`Message` on the field, `Send` on the send button), or the in-memory backend's `Welcome` channel | Fix the chat UI test in `MCP/src/guide.ts` and the `hasChatUITest` check in `MCP/src/project.ts`; customers' generated UI tests find the composer by these labels |
| A Showcase demo is added, removed, renamed, or changed | Nothing in `MCP/`; the demo index is built when the package is packed. Keep the demo in its own `Showcase/<Name>/` folder with the `<Name>Demo` view and the first sentence of its `///` comment, which is the demo's description. Name anything new in `Shared/` with `Sample` |
| What a tool does, or how the catalog is structured | Update this document first |

## Package layout

```
MCP/
├─ package.json        Single source for dependencies and the version; the version is the SDK version it guides
├─ src/
│  ├─ index.ts         stdio entry point (run by npx)
│  ├─ server.ts        Tool registration and the server instructions
│  ├─ project.ts       Reads the customer's project and matches its sources for the step checks
│  ├─ guide.ts         Step checks and instructions, including the Swift snippets
│  ├─ packageLink.ts   add_package: links the product into project.pbxproj and checks the result
│  ├─ catalog.ts       The catalog's types, reading it, and rendering list_components and describe_component
│  ├─ demos.ts         The demo index's types, reading it, and rendering show_demo
│  └─ version.ts       The version from package.json
├─ catalog/            Shipped
│  ├─ components.json  The generated component catalog
│  └─ examples/        One hand-written placement example per component
├─ demos/              Shipped, generated by scripts/packDemos.ts at prepack and before tests, git-ignored: the Showcase demo files and their index
├─ scripts/            Repository tooling, not shipped: generateCatalog.ts (runs xcodebuild), catalog.ts (symbol graphs to catalog), buildExamples.ts (compiles the examples), demoIndex.ts and packDemos.ts (build the demo index and copy the demos)
└─ test/               node:test; fixtures, symbol-graph builders, and the setup walk under support/; Xcode 26 app projects and existing apps (a TabView app, a NavigationStack app) under fixtures/
```

## Where the guidance comes from, and versions

- **Component facts are not written by hand.** They come from the public symbols and their `///` comments ("Component catalog"), because a hand-written list goes stale when the API changes.
- **Demos are not written for the MCP.** They are the Showcase demos as built and checked in this repository, shipped with the package rather than linked, so the code an agent reads matches the SDK version the customer installed, and it is readable while the repository is private.
- **Hand-written guidance (tutorial steps, placement examples, explanations of the rules) lives in `MCP/`.** "Keeping the MCP in step with the SDK" says which PRs update it.
- **The server and the SDK ship under the same tag and the same version number.** The server tells the agent to install the SDK version equal to its own, because guiding by 1.3 while the customer has 1.2 breaks the build.
- Guidance and tool descriptions are written in English; the reader is the customer's agent.

## Why a separate package

- The SDK package declares only iOS ([ARCHITECTURE.md](../../ARCHITECTURE.md) section 8). The server is a Node program that runs on the customer's Mac, so it cannot live in the same package.
- There is no dependency either way. The SDK targets do not know the server, and the shipped server never builds against the SDK. Only the repository tooling in `MCP/scripts/` builds the SDK, to generate the catalog.
- It lives in the same repository so the public API and the guidance change together, in one PR.

## Backend neutrality

The server follows product direction 1 too. Its guidance covers `ChatBackend`, the boundary protocols, and the adapter rules only. It never names a specific backend SDK, its install steps, or its mapping rules. Guidance for connecting a particular backend comes from that backend's adapter package, outside this repository.

## Not decided yet

- **How adapters are checked.** Whether to ship a contract test kit as a new SDK product. It is a new public product, so it is decided separately.
- **A sample backend for the tutorial.** Showing a screen before any backend exists needs an in-memory backend; today the tutorial hands one over as a snippet.
- **The npm package name and publishing account.** Until then `package.json` stays `private: true` so it cannot be published by accident.
- **Compiling the Swift snippets in `guide.ts` automatically.** The placement examples are compiled by `catalog:check`; the snippets in `guide.ts` are still compiled by hand ([AGENTS.md](../../AGENTS.md) "테스트 / 검증").
