import Foundation
import AnyChatCore

/// Everything a channel row needs in order to render, derived from a `ChatChannel`.
///
/// Some of the text depends on the current time, so the list compares and diffs on this type
/// rather than on the channel.
nonisolated struct ChannelRowState: Hashable, Identifiable {
    var id: String { channelID }

    let channelID: String
    let title: String
    let memberCountText: String?
    let isBroadcast: Bool
    let isFrozen: Bool
    let isNotificationOff: Bool
    let canLeave: Bool
    let canToggleNotifications: Bool
    let lastUpdatedText: String?
    let previewText: String
    let previewTruncation: MessagePreviewFormatter.Truncation
    let showsUnreadMention: Bool
    let unreadCountText: String?
    let receipt: ChatMessage.Receipt?
    let cover: ChannelCover
    /// `true` while a leave or notification request for this channel is in flight.
    var isActionPending: Bool

    static func make(
        channel: ChatChannel,
        currentUserID: String?,
        now: Date,
        options: ChannelListOptions,
        isActionPending: Bool = false
    ) -> ChannelRowState {
        let preview = MessagePreviewFormatter.preview(for: channel, options: options)

        return ChannelRowState(
            channelID: channel.id,
            title: ChannelNameFormatter.title(for: channel, currentUserID: currentUserID),
            memberCountText: CountFormatter.memberCountText(channel.memberCount),
            isBroadcast: channel.isBroadcast,
            isFrozen: channel.isFrozen,
            isNotificationOff: channel.notificationLevel == .off,
            canLeave: channel.canLeave,
            canToggleNotifications: channel.notificationLevel != nil,
            lastUpdatedText: ChannelTimeFormatter.lastUpdatedText(for: channel, now: now),
            previewText: preview.text,
            previewTruncation: preview.truncation,
            showsUnreadMention: options.isMentionBadgeEnabled && (channel.unreadMentionCount ?? 0) > 0,
            unreadCountText: CountFormatter.unreadText(channel.unreadMessageCount),
            receipt: ReceiptStateResolver.receipt(for: channel, currentUserID: currentUserID, options: options),
            cover: ChannelCover.resolve(for: channel, currentUserID: currentUserID),
            isActionPending: isActionPending
        )
    }
}
