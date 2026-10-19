# AnyChat

A native SwiftUI chat UI kit for messaging apps and AI agents. Bring any backend: implement the `ChatBackend` protocol, and the kit draws the screens.

> **Status: beta.** The public API may change between 0.x releases.

## What's included

- `ChannelListView`: the list of channels, with unread counts, paging, and pull to refresh.
- `ChannelView`: one channel's messages and the composer, with attachments, replies, reactions, retry for failed sends, and a jump-to-latest button.
- Light, dark, and system-adaptive themes, plus view slots to replace parts of a row, a message, or the composer.
- Building blocks for AI agent chats: streaming text, a stop button while a response is in progress (`composerStopButton`), and a scroll mode that moves the question to the top (`messageScrollBehavior(.questionToTop)`).

## Requirements

| | Version |
|---|---|
| iOS | 18.0+ |
| Swift | 6.0+ (Swift 6 language mode) |
| Xcode | 26.0+ |

## Installation

Add the package with Swift Package Manager and use the `AnyChatUI` product:

```swift
.package(url: "https://github.com/enebin/AnyChat", from: "0.1.0")
```

## Usage

The host app or an adapter owns the backend connection (initialization, sign-in). The kit assumes the registered backend is ready to use.

```swift
import AnyChatUI

// 1. Implement the backend. Each repository streams full snapshots of its list.
@MainActor
final class MyChatBackend: ChatBackend {
    var currentUserID: String? { ... }
    func makeChannelListRepository() -> any ChannelListRepository { ... }
    func makeChannelRepository(channelID: String) -> any ChannelRepository { ... }
}

// 2. Register it once at the app root. The host owns the NavigationStack.
NavigationStack {
    ChannelListView()
        .onChannelSelected { channel in selectedChannel = channel }
        .navigationDestination(item: $selectedChannel) { channel in
            ChannelView(channel: channel)
        }
}
.chatBackend(MyChatBackend())
```

If no backend is registered, the screens do not crash. They show a "Chat is unavailable" state instead. To give one screen different data, use `ChannelListView(repository:currentUserID:)` or `ChannelView(channel:repository:currentUserID:)`.

The rules an adapter must follow are in [`docs/architecture/backend-boundary.md`](docs/architecture/backend-boundary.md). An in-memory backend you can copy is in [`Examples/QuickStart/Shared/SampleChatBackend.swift`](Examples/QuickStart/Shared/SampleChatBackend.swift).

### Customization

There is no global configuration. Chain view modifiers; each one applies only to that view instance.

```swift
ChannelListView()
    .channelCoverImage { channel in MyAvatarView(channel: channel) }
    .channelUnreadCount { channel in MyBadge(count: channel.unreadMessageCount) }
    .navigationTitleText("Messages")
    .onCreateChannelTapped { isPresentingCreate = true }
    .channelListTheme(.dark)
```

The built-in themes use Apple system colors, SF Symbols, and Dynamic Type text styles. Change colors and fonts with `ChannelListTheme` and `ChannelTheme`, and replace content or layout through view slots.

## Demo apps

Every demo uses an in-memory backend, so it runs with no account or network.

| App | Shows |
|---|---|
| `Examples/QuickStart` | The default screens. Its `Showcase` scheme shows themes, slots, and streaming text. |
| `Examples/Lumen` | An AI assistant chat built from slots and custom content |
| `Examples/Prism` | A social-app style direct-message inbox |

```bash
cd Examples/QuickStart
xcodegen generate
open QuickStart.xcodeproj
```

## MCP server

`MCP/` holds an MCP server that guides a coding agent through adding AnyChat to an iOS app: setup, UI customization, and backend connection.

```bash
claude mcp add anychat -- npx -y anychat-mcp
```

Other clients and details are in [`MCP/README.md`](MCP/README.md). How it works is in [`docs/architecture/mcp.md`](docs/architecture/mcp.md).

## Contributing

Structure decisions are in [`ARCHITECTURE.md`](ARCHITECTURE.md). Working rules are in [`AGENTS.md`](AGENTS.md).

## License

AnyChat is available under the MIT license. See [`LICENSE`](LICENSE).
