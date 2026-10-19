import AnyChatDesignSystem
import SwiftUI

/// Colours and fonts for the channel list.
///
/// Apply one with `View.channelListTheme(_:)`. The default follows the system appearance.
nonisolated public struct ChannelListTheme: Sendable, Equatable {
    // MARK: Row colours

    public var background: Color
    public var titleText: Color
    public var memberCountText: Color
    public var lastUpdatedTimeText: Color
    /// The chevron after the time.
    ///
    /// - Since: 1.0.0
    public var chevronTint: Color
    /// Also tints the muted-channel bell.
    public var messageText: Color
    public var broadcastMark: Color
    public var frozenMark: Color
    public var unreadBadgeBackground: Color
    public var unreadBadgeText: Color
    public var unreadMentionText: Color
    public var receiptSent: Color
    public var receiptDelivered: Color
    public var receiptRead: Color
    public var separator: Color

    // MARK: Cover colours

    public var coverPlaceholderBackground: Color
    public var coverPlaceholderTint: Color
    public var broadcastCoverBackground: Color
    public var broadcastCoverTint: Color

    // MARK: Swipe action and bar colours

    public var leaveActionBackground: Color
    public var notificationOnActionBackground: Color
    /// Kept dark on purpose: SwiftUI renders swipe action labels in white.
    public var notificationOffActionBackground: Color
    public var barButtonTint: Color
    /// Tints the glyph and the message of the empty and error states.
    public var placeholderTint: Color

    // MARK: Fonts

    public var titleFont: Font
    public var memberCountFont: Font
    public var lastUpdatedTimeFont: Font
    public var messageFont: Font
    public var unreadBadgeFont: Font
    public var unreadMentionFont: Font

    /// Creates a theme. Anything left `nil` falls back to the light-appearance default.
    ///
    /// - Since: 1.0.0
    public init(
        background: Color? = nil,
        titleText: Color? = nil,
        memberCountText: Color? = nil,
        lastUpdatedTimeText: Color? = nil,
        chevronTint: Color? = nil,
        messageText: Color? = nil,
        broadcastMark: Color? = nil,
        frozenMark: Color? = nil,
        unreadBadgeBackground: Color? = nil,
        unreadBadgeText: Color? = nil,
        unreadMentionText: Color? = nil,
        receiptSent: Color? = nil,
        receiptDelivered: Color? = nil,
        receiptRead: Color? = nil,
        separator: Color? = nil,
        coverPlaceholderBackground: Color? = nil,
        coverPlaceholderTint: Color? = nil,
        broadcastCoverBackground: Color? = nil,
        broadcastCoverTint: Color? = nil,
        leaveActionBackground: Color? = nil,
        notificationOnActionBackground: Color? = nil,
        notificationOffActionBackground: Color? = nil,
        barButtonTint: Color? = nil,
        placeholderTint: Color? = nil,
        titleFont: Font? = nil,
        memberCountFont: Font? = nil,
        lastUpdatedTimeFont: Font? = nil,
        messageFont: Font? = nil,
        unreadBadgeFont: Font? = nil,
        unreadMentionFont: Font? = nil
    ) {
        self.background = background ?? ChatPalette.light.background
        self.titleText = titleText ?? ChatPalette.light.label
        self.memberCountText = memberCountText ?? ChatPalette.light.secondaryLabel
        self.lastUpdatedTimeText = lastUpdatedTimeText ?? ChatPalette.light.secondaryLabel
        self.chevronTint = chevronTint ?? ChatPalette.light.tertiaryLabel
        self.messageText = messageText ?? ChatPalette.light.secondaryLabel
        self.broadcastMark = broadcastMark ?? ChatPalette.light.accent
        self.frozenMark = frozenMark ?? ChatPalette.light.secondaryLabel
        self.unreadBadgeBackground = unreadBadgeBackground ?? ChatPalette.light.accent
        self.unreadBadgeText = unreadBadgeText ?? ChatPalette.onAccent
        self.unreadMentionText = unreadMentionText ?? ChatPalette.light.accent
        self.receiptSent = receiptSent ?? ChatPalette.light.tertiaryLabel
        self.receiptDelivered = receiptDelivered ?? ChatPalette.light.tertiaryLabel
        self.receiptRead = receiptRead ?? ChatPalette.light.accent
        self.separator = separator ?? ChatPalette.light.separator
        self.coverPlaceholderBackground = coverPlaceholderBackground ?? ChatPalette.light.avatarBackground
        self.coverPlaceholderTint = coverPlaceholderTint ?? ChatPalette.onAccent
        self.broadcastCoverBackground = broadcastCoverBackground ?? ChatPalette.light.accent
        self.broadcastCoverTint = broadcastCoverTint ?? ChatPalette.onAccent
        self.leaveActionBackground = leaveActionBackground ?? ChatPalette.light.destructive
        self.notificationOnActionBackground = notificationOnActionBackground ?? ChatPalette.light.accent
        self.notificationOffActionBackground = notificationOffActionBackground ?? ChatPalette.light.neutral
        self.barButtonTint = barButtonTint ?? ChatPalette.light.accent
        self.placeholderTint = placeholderTint ?? ChatPalette.light.secondaryLabel
        self.titleFont = titleFont ?? ChatTypography.headline
        self.memberCountFont = memberCountFont ?? ChatTypography.captionEmphasized
        self.lastUpdatedTimeFont = lastUpdatedTimeFont ?? ChatTypography.listTime
        self.messageFont = messageFont ?? ChatTypography.listPreview
        self.unreadBadgeFont = unreadBadgeFont ?? ChatTypography.captionEmphasized
        self.unreadMentionFont = unreadMentionFont ?? ChatTypography.headline
    }
}

// MARK: - Built-in themes

public extension ChannelListTheme {
    /// The light appearance.
    ///
    /// - Since: 1.0.0
    static let light = ChannelListTheme()

    /// The dark appearance.
    ///
    /// - Since: 1.0.0
    static let dark = ChannelListTheme(
        background: ChatPalette.dark.background,
        titleText: ChatPalette.dark.label,
        memberCountText: ChatPalette.dark.secondaryLabel,
        lastUpdatedTimeText: ChatPalette.dark.secondaryLabel,
        chevronTint: ChatPalette.dark.tertiaryLabel,
        messageText: ChatPalette.dark.secondaryLabel,
        broadcastMark: ChatPalette.dark.accent,
        frozenMark: ChatPalette.dark.secondaryLabel,
        unreadBadgeBackground: ChatPalette.dark.accent,
        unreadBadgeText: ChatPalette.onAccent,
        unreadMentionText: ChatPalette.dark.accent,
        receiptSent: ChatPalette.dark.tertiaryLabel,
        receiptDelivered: ChatPalette.dark.tertiaryLabel,
        receiptRead: ChatPalette.dark.accent,
        separator: ChatPalette.dark.separator,
        coverPlaceholderBackground: ChatPalette.dark.avatarBackground,
        coverPlaceholderTint: ChatPalette.onAccent,
        broadcastCoverBackground: ChatPalette.dark.accent,
        broadcastCoverTint: ChatPalette.onAccent,
        leaveActionBackground: ChatPalette.dark.destructive,
        notificationOnActionBackground: ChatPalette.dark.accent,
        notificationOffActionBackground: ChatPalette.dark.neutral,
        barButtonTint: ChatPalette.dark.accent,
        placeholderTint: ChatPalette.dark.secondaryLabel
    )

    /// Follows the system appearance. This is the default.
    ///
    /// - Since: 1.0.0
    static let adaptive = ChannelListTheme(
        background: pair(\.background),
        titleText: pair(\.titleText),
        memberCountText: pair(\.memberCountText),
        lastUpdatedTimeText: pair(\.lastUpdatedTimeText),
        chevronTint: pair(\.chevronTint),
        messageText: pair(\.messageText),
        broadcastMark: pair(\.broadcastMark),
        frozenMark: pair(\.frozenMark),
        unreadBadgeBackground: pair(\.unreadBadgeBackground),
        unreadBadgeText: pair(\.unreadBadgeText),
        unreadMentionText: pair(\.unreadMentionText),
        receiptSent: pair(\.receiptSent),
        receiptDelivered: pair(\.receiptDelivered),
        receiptRead: pair(\.receiptRead),
        separator: pair(\.separator),
        coverPlaceholderBackground: pair(\.coverPlaceholderBackground),
        coverPlaceholderTint: pair(\.coverPlaceholderTint),
        broadcastCoverBackground: pair(\.broadcastCoverBackground),
        broadcastCoverTint: pair(\.broadcastCoverTint),
        leaveActionBackground: pair(\.leaveActionBackground),
        notificationOnActionBackground: pair(\.notificationOnActionBackground),
        notificationOffActionBackground: pair(\.notificationOffActionBackground),
        barButtonTint: pair(\.barButtonTint),
        placeholderTint: pair(\.placeholderTint)
    )

    private static func pair(_ keyPath: KeyPath<ChannelListTheme, Color>) -> Color {
        ChatPalette.adaptive(light: light[keyPath: keyPath], dark: dark[keyPath: keyPath])
    }
}
