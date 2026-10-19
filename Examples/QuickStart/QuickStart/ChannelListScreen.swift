import SwiftUI
import AnyChatUI

/// Hosts the UI Kit's channel list, pushes the channel screen, and reacts to list events.
struct ChannelListScreen: View {
    let replies: SampleReplies

    @State private var selectedChannel: ChatChannel?
    @State private var message: String?
    @State private var selectedAttachment: ChatAttachment?
    @State private var doubleTappedText: String?

    var body: some View {
        ChannelListView()
            .channelListHeader {
                if showsCustomizationDemo { NotesStrip { message = "\($0) tapped." } }
            }
            .onChannelSelected { channel in
                selectedChannel = channel
            }
            .onCreateChannelTapped {
                message = "Channel creation is not part of this release yet."
            }
            .onLeaveChannel { channel in
                message = "Left \(channel.name ?? channel.id)."
            }
            .onError { error in
                message = error.localizedDescription
            }
            .navigationDestination(item: $selectedChannel) { channel in
                FreezableChannelView(channel: channel, replies: replies) { attachment in
                    selectedAttachment = attachment
                } onMessageDoubleTapped: { message in
                    if case let .text(text) = message.content {
                        doubleTappedText = text
                    }
                }
                .alert("Attachment", isPresented: showsAttachment) {
                    Button("OK") { selectedAttachment = nil }
                } message: {
                    Text(selectedAttachment?.fileName ?? "")
                }
                .alert("Double-tapped", isPresented: showsDoubleTappedMessage) {
                    Button("OK") { doubleTappedText = nil }
                } message: {
                    Text(doubleTappedText ?? "")
                }
            }
            .alert("QuickStart", isPresented: showsMessage) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
    }

    private var showsCustomizationDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_CUSTOMIZATION_DEMO"] == "1"
    }

    private var showsAttachment: Binding<Bool> {
        Binding(get: { selectedAttachment != nil }, set: { if !$0 { selectedAttachment = nil } })
    }

    private var showsDoubleTappedMessage: Binding<Bool> {
        Binding(get: { doubleTappedText != nil }, set: { if !$0 { doubleTappedText = nil } })
    }

    private var showsMessage: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}

/// Two buttons with blank space between them, so the UI tests can tell a button's tap from a tap
/// on the rest of the header.
private struct NotesStrip: View {
    let onTap: (String) -> Void

    var body: some View {
        HStack {
            Button("New note") { onTap("New note") }
            Spacer()
            Button("See all") { onTap("See all") }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("channelListHeader")
    }
}

/// Passes newer values of the channel to the same `ChannelView`, which follows them.
private struct FreezableChannelView: View {
    @State private var channel: ChatChannel
    @State private var didTapLeadingButton = false
    let replies: SampleReplies
    let onAttachmentSelected: (ChatAttachment) -> Void
    let onMessageDoubleTapped: (ChatMessage) -> Void

    init(
        channel: ChatChannel,
        replies: SampleReplies,
        onAttachmentSelected: @escaping (ChatAttachment) -> Void,
        onMessageDoubleTapped: @escaping (ChatMessage) -> Void
    ) {
        _channel = State(initialValue: channel)
        self.replies = replies
        self.onAttachmentSelected = onAttachmentSelected
        self.onMessageDoubleTapped = onMessageDoubleTapped
    }

    var body: some View {
        overlayChannel
            .onAttachmentSelected { attachment, _ in
                onAttachmentSelected(attachment)
            }
            .onMessageDoubleTapped { message, _ in
                onMessageDoubleTapped(message)
            }
            .composerStopButton(isResponding: replies.isResponding(channelID: channel.id)) {
                replies.stop(channelID: channel.id)
            }
            .composerLeadingItems { context in
                if showsCustomizationDemo {
                    Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
                        .accessibilityLabel("Gallery")
                }
                context.defaultItems
            }
            .messageAccessory { message, _ in
                if showsCustomizationDemo, let reactions = message.attributes[SampleReactions.self] {
                    ReactionBadges(reactions: reactions)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if showsSwitchDemo, let empty = SampleData.channels(now: Date()).first(where: { $0.id == SampleData.emptyChannelID }) {
                        Button { channel = empty } label: { Image(systemName: "arrow.left.arrow.right") }
                            .accessibilityLabel("Open \(empty.name ?? empty.id)")
                    } else if showsCustomizationDemo { Button(channel.isFrozen ? "Unfreeze" : "Freeze") {
                        channel.isFrozen.toggle()
                        channel.canSendMessage = !channel.isFrozen
                    } }
                }
                if showsHiddenHeaderDemo {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Chats", systemImage: "line.3.horizontal") { didTapLeadingButton = true }
                            .accessibilityIdentifier("hostLeadingButton")
                    }
                }
            }
            .alert("Leading button tapped", isPresented: $didTapLeadingButton) {
                Button("OK") {}
            }
    }

    /// Swaps the open channel for the empty one on the same screen, as an app that reuses one
    /// channel screen for a new chat does. It takes the Freeze button's place, which an extra item
    /// would push into an overflow menu, so it has its own switch.
    private var showsSwitchDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_SWITCH_DEMO"] == "1"
    }
    private var showsCustomizationDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_CUSTOMIZATION_DEMO"] == "1"
    }

    /// The long-press overlay replaces the system menu, so it has its own switch and the menu's
    /// tests keep the default.
    private var showsOverlayDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_OVERLAY_DEMO"] == "1"
    }

    /// An empty header leaves the leading spot to the host's own toolbar button.
    private var showsHiddenHeaderDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_HIDDEN_HEADER_DEMO"] == "1"
    }

    /// Moves a sent message to the top, as an AI chat does. The other tests check the default.
    private var showsQuestionToTopDemo: Bool {
        ProcessInfo.processInfo.environment["QUICKSTART_QUESTION_TO_TOP_DEMO"] == "1"
    }

    private var overlayChannel: ChannelView {
        let screen = configuredChannel.messageScrollBehavior(showsQuestionToTopDemo ? .questionToTop : .followsLatest)
        guard showsOverlayDemo else { return screen }
        return screen.messageLongPressOverlay { message, context in
            if message.sendingStatus == nil {
                ReactionBar { context.dismiss() }
            }
        } below: { _, context in
            context.defaultItems
        }
    }

    private var configuredChannel: ChannelView {
        if showsHiddenHeaderDemo {
            return ChannelView(channel: channel)
                .channelHeader { _ in EmptyView() }
        } else if showsCustomizationDemo {
            return ChannelView(channel: channel)
                .channelHeader { ChannelHeaderTitle(channel: $0) }
                .messageDateSeparator { separator in
                    Text(separator.day.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("customDateSeparator")
                }
                .channelEmptyState { EmptyChannelGreeting(channel: channel, composer: $0) }
        } else {
            return ChannelView(channel: channel)
        }
    }
}

/// A picture, a name, and a subtitle, which the navigation bar would clip without the screen's sizing.
private struct ChannelHeaderTitle: View {
    let channel: ChatChannel

    var body: some View {
        HStack(spacing: 8) {
            Text(initials)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.blue, in: Circle())
                .accessibilityIdentifier("channelHeaderPicture")
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.headline)
                    .accessibilityIdentifier("channelHeaderName")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("channelHeaderSubtitle")
            }
        }
    }

    private var name: String {
        channel.name ?? channel.id
    }

    private var initials: String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    private var subtitle: String {
        channel.memberCount.map { "\($0) members" } ?? "Channel"
    }
}

/// Sits at the bottom of the list's area, so the UI tests can see it stay above the composer. Its
/// button sends through the screen's composer context.
private struct EmptyChannelGreeting: View {
    let channel: ChatChannel
    let composer: ComposerContext

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            VStack(spacing: 4) {
                Text("Nothing in \(channel.name ?? "this channel") yet")
                    .font(.headline)
                Text("Say hi to get it started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("channelEmptyState")
            Button("Say hi 👋") { composer.send(text: "Hi everyone 👋") }
                .buttonStyle(.bordered)
                .disabled(!composer.canSend)
        }
        .padding(.bottom, 16)
    }
}

private struct ReactionBar: View {
    let onPick: () -> Void

    private let reactions = [("❤️", "Heart"), ("👍", "Thumbs up"), ("😂", "Laugh")]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.1) { emoji, name in
                Button(emoji, action: onPick)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(name)
            }
        }
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: Capsule())
    }
}

private struct ReactionBadges: View {
    let reactions: SampleReactions

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions.reactions, id: \.self) { reaction in
                Text("\(reaction.emoji) \(reaction.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel("\(reaction.name) \(reaction.count)")
            }
        }
    }
}
