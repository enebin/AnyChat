import SwiftUI
import AnyChatUI

struct InboxScreen: View {
    let backend: PrismBackend

    @State private var selected: ChatChannel?
    @State private var isComposing = false

    var body: some View {
        NavigationStack {
            ChannelListView()
                .channelListHeader {
                    VStack(spacing: 0) {
                        NotesStrip()
                        HStack {
                            Text("Messages").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("Requests").font(.system(size: 15, weight: .semibold)).foregroundStyle(PrismStyle.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .channelRow { InboxRow(channel: $0) }
                .createChannelButtonLabel {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                        .accessibilityLabel("New message")
                }
                .onCreateChannelTapped { isComposing = true }
                .onChannelSelected { selected = $0 }
                .navigationTitleText(PrismSampleData.profiles[PrismBackend.me.id]?.handle ?? "")
                .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { channel in
                ThreadScreen(channel: channel, backend: backend)
            }
            .sheet(isPresented: $isComposing) {
                NewMessageSheet { person in
                    isComposing = false
                    selected = backend.channel(with: person)
                }
            }
        }
        .tint(.primary)
    }
}

/// One conversation in the inbox: picture, name, and the latest activity, bold while unread.
struct InboxRow: View {
    let channel: ChatChannel

    private var isUnread: Bool { (channel.unreadMessageCount ?? 0) > 0 }

    var body: some View {
        HStack(spacing: 12) {
            if let friend = channel.friend {
                PrismAvatar(person: friend)
            } else {
                PrismGroupAvatar(members: channel.members)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name ?? "")
                    .font(.system(size: 15, weight: isUnread ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(preview)
                        .lineLimit(1)
                    if let date = channel.lastMessage?.createdAt, channel.typingUsers.isEmpty {
                        Text("· \(date.shortAgo)").layoutPriority(1)
                    }
                }
                .font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                .foregroundStyle(isUnread ? .primary : .secondary)
            }
            Spacer(minLength: 8)
            if isUnread {
                Circle().fill(PrismStyle.accent).frame(width: 8, height: 8)
                    .accessibilityLabel("Unread")
            }
            Image(systemName: "camera")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    var preview: String {
        if let typing = channel.typingUsers.first {
            return channel.friend == nil ? "\(typing.name ?? "Someone") is typing..." : "typing..."
        }
        guard let message = channel.lastMessage else {
            return "Say hi 👋"
        }
        let isMine = message.sender?.id == PrismBackend.me.id
        let body: String
        switch message.content {
        case .text(let text):
            if !message.attachments.isEmpty {
                return attachmentPreview(kinds: message.attachments.map(\.kind), isMine: isMine)
            }
            body = text
        case .file(let kind):
            return attachmentPreview(kinds: message.attachments.isEmpty ? [kind] : message.attachments.map(\.kind), isMine: isMine)
        case .files:
            return attachmentPreview(kinds: message.attachments.map(\.kind), isMine: isMine)
        case .system(let text):
            body = text
        case .unsupported:
            body = "Sent a message"
        }
        if isMine {
            if message.receipt == .read, let friend = channel.friend {
                return "Seen by \(friend.name?.split(separator: " ").first.map(String.init) ?? "them")"
            }
            return "You: \(body)"
        }
        if channel.friend == nil, let name = message.sender?.name?.split(separator: " ").first {
            return "\(name): \(body)"
        }
        return body
    }

    private func attachmentPreview(kinds: [ChatMessage.FileKind], isMine: Bool) -> String {
        let description: String
        if kinds.count == 1, let kind = kinds.first {
            description = switch kind {
            case .image: "a photo"
            case .gif: "a GIF"
            case .video: "a video"
            case .audio: "an audio file"
            case .voice: "a voice message"
            case .other: "a file"
            }
        } else {
            description = "files"
        }
        return isMine ? "You sent \(description)" : "Sent \(description)"
    }
}
