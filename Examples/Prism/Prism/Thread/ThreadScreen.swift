import SwiftUI
import AnyChatUI

struct ThreadScreen: View {
    let channel: ChatChannel
    let backend: PrismBackend

    private let avatarSize: CGFloat = 28

    var body: some View {
        ChannelView(channel: channel)
            .channelHeader { ThreadHeader(channel: $0) }
            .messageAvatar { message, _ in
                if let sender = message.sender {
                    PrismAvatar(person: sender, size: avatarSize, showsStory: false, showsActivity: false)
                } else {
                    Color.clear.frame(width: avatarSize, height: avatarSize)
                }
            }
            .messageSenderName { message, _ in
                // A one-to-one thread's header already names the other person.
                if channel.friend == nil, let name = message.sender?.name?.split(separator: " ").first {
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .messageTime { _, _ in EmptyView() }
            .messageBubbleBackground { _, context in
                ThreadBubbleShape(context: context)
            }
            .messageAccessory { message, context in
                if let likes = message.attributes[Likes.self], message.sendingStatus == nil {
                    LikeBadge(count: likes.userIDs.count)
                        .padding(.top, -10)
                        .padding(context.isMine ? .trailing : .leading, 8)
                }
            }
            .onMessageDoubleTapped { message, _ in
                guard message.sendingStatus == nil else { return }
                backend.toggleLike(messageID: message.id, channelID: channel.id)
            }
            .messageContextMenu { message, context in
                if message.sendingStatus == nil {
                    let liked = message.attributes[Likes.self]?.userIDs.contains(PrismBackend.me.id) == true
                    Button(liked ? "Unlike" : "Like") {
                        backend.toggleLike(messageID: message.id, channelID: channel.id)
                    }
                }
                context.defaultItems
            }
            .composer { ThreadComposer(context: $0) }
            .toolbarTitleDisplayMode(.inline)
    }
}

private struct ThreadHeader: View {
    let channel: ChatChannel

    var body: some View {
        HStack(spacing: 10) {
            if let friend = channel.friend {
                PrismAvatar(person: friend, size: 32, showsStory: false)
            } else {
                PrismGroupAvatar(members: channel.members, size: 32)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(channel.name ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        guard let friend = channel.friend else {
            return "\(channel.members.count) members"
        }
        let profile = PrismSampleData.profile(friend)
        if profile?.isActive == true {
            return "Active now"
        }
        return profile?.handle ?? ""
    }
}

/// Rounded on every corner except where the bubble joins the one above or below it on the sender's side.
private struct ThreadBubbleShape: View {
    let context: MessageRowContext

    private let round: CGFloat = 20
    private let joined: CGFloat = 5

    var body: some View {
        let top = context.groupPosition == .middle || context.groupPosition == .last ? joined : round
        let bottom = context.groupPosition == .middle || context.groupPosition == .first ? joined : round
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: context.isMine ? round : top,
            bottomLeadingRadius: context.isMine ? round : bottom,
            bottomTrailingRadius: context.isMine ? bottom : round,
            topTrailingRadius: context.isMine ? top : round,
            style: .continuous
        )
        if context.isMine {
            shape.fill(PrismStyle.outgoingGradient)
        } else {
            shape.fill(PrismStyle.incomingBubble)
        }
    }
}

private struct LikeBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Text("❤️").font(.system(size: 12))
            if count > 1 {
                Text("\(count)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .overlay(Capsule().strokeBorder(Color(.systemBackground), lineWidth: 2))
        .accessibilityLabel(count > 1 ? "\(count) likes" : "Liked")
    }
}
