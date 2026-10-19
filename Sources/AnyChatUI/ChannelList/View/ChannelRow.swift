import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// One channel in the list.
struct ChannelRow: View {
    let row: ChannelRowState
    /// The channel handed to custom slots. `nil` in previews that have no channel.
    let channel: ChatChannel?
    var slots = ChannelListSlots()

    @Environment(\.channelListTheme) private var theme

    nonisolated private static let coverSize: CGFloat = 45
    nonisolated private static let horizontalPadding: CGFloat = 8
    nonisolated private static let coverSpacing: CGFloat = 12
    nonisolated private static let titleLineHeight: CGFloat = 22
    /// With the row's 4pt spacing and the symbol's own 2pt side bearing, this leaves the design
    /// source's 12pt between the time and the chevron.
    nonisolated private static let chevronLeadingPadding: CGFloat = 6

    /// The list separator starts where the text column does.
    ///
    /// `nonisolated` because `alignmentGuide` reads it from a Sendable closure.
    nonisolated static let separatorLeading = horizontalPadding + 18 + coverSize + coverSpacing

    private let markSize: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Circle()
                .fill(theme.unreadBadgeBackground)
                .frame(width: 10, height: 10)
                .opacity(row.unreadCountText != nil && slots.unreadCount == nil ? 1 : 0)
                .accessibilityLabel(row.unreadCountText.map { "\($0) unread messages" } ?? "")
                .accessibilityHidden(row.unreadCountText == nil || slots.unreadCount != nil)
                .frame(width: 18, height: 45, alignment: .leading)
                .padding(.top, 8)
            coverImage
                .padding(.top, 8)
                .padding(.trailing, Self.coverSpacing)
            VStack(alignment: .leading, spacing: 0) {
                titleLine
                previewLine
            }
        }
        .padding(.leading, Self.horizontalPadding)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 79, alignment: .top)
    }

    // MARK: - Cover

    @ViewBuilder
    private var coverImage: some View {
        if let slot = slots.coverImage, let channel {
            slot(channel)
        } else {
            Avatar(
                .init(row.cover),
                size: Self.coverSize,
                background: row.cover == .broadcast ? theme.broadcastCoverBackground : theme.coverPlaceholderBackground,
                tint: row.cover == .broadcast ? theme.broadcastCoverTint : theme.coverPlaceholderTint
            )
        }
    }

    // MARK: - Title line

    private var titleLine: some View {
        HStack(spacing: 4) {
            if row.isBroadcast {
                mark(.broadcast, tint: theme.broadcastMark)
            }

            channelName

            if row.isFrozen {
                mark(.freeze, tint: theme.frozenMark)
            }

            if row.isNotificationOff {
                mark(.notificationOffFilled, tint: theme.messageText)
            }

            Spacer(minLength: 4)

            if let receipt = row.receipt {
                mark(receipt == .sent ? .done : .doneAll, tint: color(for: receipt))
            }

            if let lastUpdatedText = row.lastUpdatedText {
                Text(lastUpdatedText)
                    .font(theme.lastUpdatedTimeFont)
                    .foregroundStyle(theme.lastUpdatedTimeText)
                    .layoutPriority(1)
            }
            Image(systemName: "chevron.right")
                .font(ChatTypography.listChevron)
                .foregroundStyle(theme.chevronTint)
                .padding(.leading, Self.chevronLeadingPadding)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Self.titleLineHeight)
    }

    @ViewBuilder
    private var channelName: some View {
        if let slot = slots.channelName, let channel {
            slot(channel)
        } else {
            Text(row.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.titleText)
                .lineLimit(1)
        }
    }

    // MARK: - Preview line

    private var previewLine: some View {
        HStack(alignment: .top, spacing: 4) {
            channelPreview

            Spacer(minLength: 4)

            if row.showsUnreadMention {
                Text("@")
                    .font(theme.unreadMentionFont)
                    .foregroundStyle(theme.unreadMentionText)
            }

            unreadCount
        }
    }

    @ViewBuilder
    private var channelPreview: some View {
        if let slot = slots.channelPreview, let channel {
            slot(channel)
        } else {
            Text(row.previewText)
                .font(theme.messageFont)
                .foregroundStyle(theme.messageText)
                .lineLimit(2)
                .truncationMode(row.previewTruncation == .middle ? .middle : .tail)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var unreadCount: some View {
        if let slot = slots.unreadCount, let channel {
            slot(channel)

        }
    }

    // MARK: - Helpers

    private func mark(_ icon: ChatIcon, tint: Color) -> some View {
        icon.sized(markSize)
            .foregroundStyle(tint)
    }

    private func color(for receipt: ChatMessage.Receipt) -> Color {
        switch receipt {
        case .sent: theme.receiptSent
        case .delivered: theme.receiptDelivered
        case .read: theme.receiptRead
        }
    }
}

#Preview("Rows") {
    List {
        ChannelRow(row: .preview(), channel: nil)
        ChannelRow(
            row: .preview(
                title: "Design, Marketing, Support",
                memberCountText: "3.2K",
                isBroadcast: true,
                isFrozen: true,
                isNotificationOff: true,
                previewText: "A much longer message that has to wrap onto a second line before it stops",
                showsUnreadMention: true,
                unreadCountText: "99+"
            ),
            channel: nil
        )
        ChannelRow(
            row: .preview(title: "Alice", previewText: "Voice message", receipt: .read),
            channel: nil
        )
    }
    .listStyle(.plain)
}

extension ChannelRowState {
    /// Builds a row without a channel, for previews.
    static func preview(
        channelID: String = "channel_preview",
        title: String = "Design team",
        memberCountText: String? = nil,
        isBroadcast: Bool = false,
        isFrozen: Bool = false,
        isNotificationOff: Bool = false,
        lastUpdatedText: String? = "02:04 PM",
        previewText: String = "See you tomorrow",
        showsUnreadMention: Bool = false,
        unreadCountText: String? = "3",
        receipt: ChatMessage.Receipt? = nil,
        cover: ChannelCover = .placeholder
    ) -> ChannelRowState {
        ChannelRowState(
            channelID: channelID,
            title: title,
            memberCountText: memberCountText,
            isBroadcast: isBroadcast,
            isFrozen: isFrozen,
            isNotificationOff: isNotificationOff,
            canLeave: true,
            canToggleNotifications: true,
            lastUpdatedText: lastUpdatedText,
            previewText: previewText,
            previewTruncation: .tail,
            showsUnreadMention: showsUnreadMention,
            unreadCountText: unreadCountText,
            receipt: receipt,
            cover: cover,
            isActionPending: false
        )
    }
}
