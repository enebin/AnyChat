import SwiftUI
import AnyChatUI

/// Replaces parts of the default rows, or whole rows, on the channel list and the channel screen,
/// puts a strip of notes above the channel rows, draws initials in place of senders' pictures,
/// restyles senders' names and hides them in one-to-one channels, restyles or hides message
/// times, reshapes and resizes message bubbles, adds reaction badges below them, restyles date
/// separators, and hides the channel header to put a menu of its own at the leading edge.
struct SlotDemo: View {
    @State private var backend = SampleChatBackend()
    @State private var mode = SlotMode.standard
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        channelList
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Slots")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Slots", selection: $mode) {
                        ForEach(SlotMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationDestination(item: $selectedChannel) { channel in
                channelScreen(channel)
                    .toolbar {
                        if mode == .bubble {
                            ToolbarItem(placement: .topBarLeading) { slotMenu }
                        }
                    }
                    .chatBackend(backend)
            }
            .chatBackend(backend)
    }

    /// Takes the leading spot the hidden channel header leaves.
    private var slotMenu: some View {
        Menu {
            Picker("Slots", selection: $mode) {
                ForEach(SlotMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("Slots")
    }

    private var channelList: ChannelListView {
        let list = ChannelListView()
        switch mode {
        case .standard:
            return list
        case .partial:
            // The default separator still starts after a 56pt cover, so it no longer lines up
            // with the text beside this smaller one.
            return list
                .channelListHeader { NotesStrip() }
                .channelCoverImage { InitialsAvatar(name: $0.title) }
                .channelUnreadCount { channel in
                    if let count = channel.unreadMessageCount, count > 0 {
                        NewBadge(count: count)
                    }
                }
        case .bubble:
            return list
        case .wholeRow:
            return list.channelRow { CompactChannelRow(channel: $0) }
        }
    }

    private func channelScreen(_ channel: ChatChannel) -> ChannelView {
        let screen = ChannelView(channel: channel)
        switch mode {
        case .standard:
            return screen
        case .partial:
            return screen
                .channelHeader { HeaderTitle(channel: $0) }
                .composerPlaceholder("Say something nice")
                .composerLeadingItems { context in
                    if context.canOpenCamera {
                        Button { context.openCamera() } label: { Image(systemName: "camera") }
                            .accessibilityLabel("Camera")
                    }
                    context.defaultItems
                }
                .composerTrailingItems { context in
                    Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
                        .accessibilityLabel("Photo library")
                }
                .messageContent { message, context in
                    OutlinedBubble(text: message.summary, isMine: context.isMine)
                }
                .messageContent(SamplePoll.self) { poll, _, _ in PollCard(poll: poll) }
                .messageAvatar { message, _ in InitialsAvatar(name: message.sender?.name ?? "?") }
                .messageSenderName { message, _ in
                    // A one-to-one channel's header already names the other person.
                    if channel.memberCount != 2, let name = message.sender?.name {
                        Text(name.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .messageTime { message, _ in
                    Text(message.createdAt, format: .dateTime.hour().minute())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .messageAccessory { message, _ in
                    if let reactions = message.attributes[SampleReactions.self] {
                        ReactionBadges(reactions: reactions)
                    }
                }
                .messageDateSeparator { separator in
                    Text("\(separator.day.uppercased()) · \(separator.time)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
        case .bubble:
            // The text stays the theme's colour, which reads on both fills. The tails mark the end
            // of a run, so the times beside the bubbles are left out.
            return screen
                .channelHeader { _ in EmptyView() }
                .messageBubbleLayout(insets: EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16), maxWidth: 280)
                .messageBubbleBackground { _, context in
                    TailBubble(isMine: context.isMine, hasTail: context.hasTail)
                        .fill(context.isMine ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.quaternary))
                }
                .messageTime { _, _ in EmptyView() }
        case .wholeRow:
            return screen
                .channelHeader { HeaderTitle(channel: $0) }
                .messageRow { message, context in
                    TranscriptRow(message: message, isMine: context.isMine)
                }
                .messageRow(SamplePoll.self) { poll, _, _ in
                    PollCard(poll: poll)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
        }
    }
}

private enum SlotMode: CaseIterable {
    case standard
    case partial
    case bubble
    case wholeRow

    var title: String {
        switch self {
        case .standard: "Default"
        case .partial: "Partial"
        case .bubble: "Bubble"
        case .wholeRow: "Whole row"
        }
    }
}

// MARK: - Channel list slots

private struct InitialsAvatar: View {
    let name: String

    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(.blue))
    }

    private var initials: String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }
}

/// Scrolls sideways inside the list header and scrolls up with the channel rows.
private struct NotesStrip: View {
    private let notes = [
        ("Alice", "Coffee?"),
        ("Bob", "On a train"),
        ("Carol", "Shipping today"),
        ("Dave", "Back at 3"),
        ("Erin", "Lunch?")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(notes, id: \.0) { name, note in
                    VStack(spacing: 4) {
                        Text(note)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        InitialsAvatar(name: name)
                        Text(name)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct NewBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+ new" : "\(count) new")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.orange))
    }
}

private struct CompactChannelRow: View {
    let channel: ChatChannel

    var body: some View {
        HStack {
            Text(channel.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Spacer()
            if let count = channel.unreadMessageCount, count > 0 {
                Text("\(count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Channel screen slots

private struct HeaderTitle: View {
    let channel: ChatChannel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(channel.title)
                .font(.headline)
            if let memberCount = channel.memberCount {
                Text("\(memberCount) members")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OutlinedBubble: View {
    let text: String
    let isMine: Bool

    var body: some View {
        Text(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isMine ? Color.blue : Color.secondary, lineWidth: 1.5)
            )
    }
}

private struct TranscriptRow: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(senderName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isMine ? Color.blue : Color.secondary)
                .frame(width: 56, alignment: .leading)
            Text(message.summary)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(message.createdAt, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var senderName: String {
        isMine ? "Me" : message.sender?.name ?? "System"
    }
}

private struct PollCard: View {
    let poll: SamplePoll

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(poll.question, systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
            ForEach(poll.options, id: \.self) { option in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(option.title)
                        Spacer()
                        Text("\(option.votes)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    ProgressView(value: Double(option.votes), total: Double(totalVotes))
                        .tint(.blue)
                }
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 16).fill(.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.blue.opacity(0.3)))
    }

    private var totalVotes: Int {
        max(poll.options.map(\.votes).reduce(0, +), 1)
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

/// A rounded bubble whose bottom corner on the sender's side ends in a small tail. The tail
/// sticks out 5pt, inside the spacing beside the bubble.
private struct TailBubble: Shape {
    let isMine: Bool
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius = min(16, rect.height / 2)
        var path = Path(roundedRect: rect, cornerRadius: radius)
        guard hasTail else { return path }
        let edgeX = isMine ? rect.maxX : rect.minX
        let outward: CGFloat = isMine ? 1 : -1
        path.addRect(CGRect(x: isMine ? rect.maxX - radius : rect.minX, y: rect.maxY - radius, width: radius, height: radius))
        path.move(to: CGPoint(x: edgeX, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: edgeX + outward * 5, y: rect.maxY))
        path.addLine(to: CGPoint(x: edgeX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Helpers

private extension ChatChannel {
    var title: String {
        name ?? members.filter { $0.id != SampleChatBackend.currentUserID }.compactMap(\.name).joined(separator: ", ")
    }
}

private extension MessageRowContext {
    var hasTail: Bool {
        groupPosition == .single || groupPosition == .last
    }
}

private extension ChatMessage {
    /// One line of text for a slot that replaces the default message or preview text.
    var summary: String {
        switch content {
        case .text(let text) where !text.isEmpty: text
        case .text, .files: attachments.count == 1 ? "1 attachment" : "\(attachments.count) attachments"
        case .system(let text): text
        case .file(.voice): "Voice message"
        case .file: "File"
        case .unsupported: "Unsupported message"
        }
    }
}
