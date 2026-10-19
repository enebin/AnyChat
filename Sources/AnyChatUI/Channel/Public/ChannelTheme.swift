import AnyChatDesignSystem
import SwiftUI

/// Colours and fonts for the channel screen.
///
/// Apply one with `View.channelTheme(_:)`. The default follows the system appearance.
///
/// - Since: 1.0.0
nonisolated public struct ChannelTheme: Sendable, Equatable {
    // MARK: Colours

    /// The screen background behind the messages. It also tints the glass of the long-press
    /// overlay's card.
    ///
    /// - Since: 1.0.0
    public var background: Color
    /// The channel name in the navigation bar.
    ///
    /// - Since: 1.0.0
    public var headerTitleText: Color
    /// The bubble behind messages from other people.
    ///
    /// Also the frame around a grid of images on either side, and the area behind an image or
    /// video thumbnail that has not loaded.
    ///
    /// - Since: 1.0.0
    public var incomingBubbleBackground: Color
    /// The bubble behind the current user's messages.
    ///
    /// - Since: 1.0.0
    public var outgoingBubbleBackground: Color
    /// Text inside other people's bubbles.
    ///
    /// - Since: 1.0.0
    public var incomingMessageText: Color
    /// Text inside the current user's bubbles.
    ///
    /// - Since: 1.0.0
    public var outgoingMessageText: Color
    /// The sender's name above the first bubble of a run.
    ///
    /// - Since: 1.0.0
    public var senderNameText: Color
    /// The quoted original above a reply's bubble. Its "replied to" line, and the text shown when
    /// the original is unavailable, use `senderNameText`.
    ///
    /// - Since: 1.0.0
    public var replyQuoteText: Color
    /// The outline of the quoted original above a reply's bubble.
    ///
    /// - Since: 1.0.0
    public var replyQuoteBorder: Color
    /// The time beside the last bubble of a run.
    ///
    /// - Since: 1.0.0
    public var timeText: Color
    /// Centered lines the backend writes, such as "Alice joined".
    ///
    /// - Since: 1.0.0
    public var systemMessageText: Color
    /// The pill behind the day and time above each day's first message. Clear by default.
    ///
    /// - Since: 1.0.0
    public var dateSeparatorBackground: Color
    /// The day and time above each day's first message.
    ///
    /// - Since: 1.0.0
    public var dateSeparatorText: Color
    /// The single check on a sent message.
    ///
    /// - Since: 1.0.0
    public var receiptSent: Color
    /// The double check on a delivered message.
    ///
    /// - Since: 1.0.0
    public var receiptDelivered: Color
    /// The double check on a read message.
    ///
    /// - Since: 1.0.0
    public var receiptRead: Color
    /// Behind a person or channel picture that has not loaded or does not exist.
    ///
    /// - Since: 1.0.0
    public var avatarPlaceholderBackground: Color
    /// The glyph inside that placeholder.
    ///
    /// - Since: 1.0.0
    public var avatarPlaceholderTint: Color
    /// Behind the glyph of a broadcast channel's picture in the header.
    ///
    /// - Since: 1.0.0
    public var broadcastCoverBackground: Color
    /// The glyph of a broadcast channel's picture in the header.
    ///
    /// - Since: 1.0.0
    public var broadcastCoverTint: Color
    /// The retry button and the loading spinners.
    ///
    /// - Since: 1.0.0
    public var accent: Color
    /// The glyph and the message of the empty and error states.
    ///
    /// - Since: 1.0.0
    public var placeholderTint: Color
    /// The tile behind a file attachment's icon.
    ///
    /// - Since: 1.0.0
    public var fileIconBackground: Color
    /// A file attachment's icon.
    ///
    /// - Since: 1.0.0
    public var fileIconTint: Color
    /// The photo icon shown while an image or video thumbnail loads or after it fails.
    ///
    /// The area behind it uses `incomingBubbleBackground`.
    ///
    /// - Since: 1.0.0
    public var mediaPlaceholderTint: Color
    /// The circle behind the GIF and play badges on thumbnails.
    ///
    /// - Since: 1.0.0
    public var mediaBadgeBackground: Color
    /// The GIF and play glyphs on thumbnails.
    ///
    /// - Since: 1.0.0
    public var mediaBadgeTint: Color
    /// The bar behind the message composer, down to the bottom of the screen.
    /// `ChannelView.composerBackground(_:)` replaces it with a view of your own, such as a gradient.
    ///
    /// - Since: 1.0.0
    public var composerBackground: Color
    /// The rounded field the user types into.
    ///
    /// - Since: 1.0.0
    public var composerFieldBackground: Color
    /// The text being typed, and the labels of the long-press overlay's card rows.
    ///
    /// - Since: 1.0.0
    public var composerText: Color
    /// The placeholder in an empty field.
    ///
    /// - Since: 1.0.0
    public var composerPlaceholderText: Color
    /// The add and send buttons.
    ///
    /// - Since: 1.0.0
    public var composerButtonTint: Color
    /// The text cursor in the field. Left `nil` in the initializer, it takes `composerButtonTint`
    /// when that is given, so a theme that sets only the button tint keeps one colour.
    ///
    /// - Since: 1.0.0
    public var composerCursor: Color
    /// The circle behind the reply bar's close button. The bar's title uses `composerText`, its
    /// preview `replyQuoteText`, its background `composerFieldBackground`, and the close glyph
    /// `senderNameText`. It also fills a long-press overlay card row while it is pressed.
    ///
    /// - Since: 1.0.0
    public var replyBarCloseBackground: Color
    /// The placeholder and the add button while the composer is disabled.
    ///
    /// - Since: 1.0.0
    public var composerDisabledTint: Color
    /// The spinner beside a message that is still sending.
    ///
    /// - Since: 1.0.0
    public var sendingIndicatorTint: Color
    /// The error icon beside a message that failed to send, and destructive rows in the long-press
    /// overlay's card.
    ///
    /// - Since: 1.0.0
    public var failedIndicatorTint: Color
    /// The banner at the top of a frozen channel.
    ///
    /// - Since: 1.0.0
    public var frozenBannerBackground: Color
    /// The text of the frozen channel banner.
    ///
    /// - Since: 1.0.0
    public var frozenBannerText: Color
    /// The tint over the messages and the composer while a long-pressed message shows the views
    /// of `ChannelView.messageLongPressOverlay(above:below:)`. The default is the same in light and
    /// dark. The card below the bubble takes its glass tint from `background`, its row labels from
    /// `messageFont` and `composerText` (`failedIndicatorTint` for destructive rows), and its pressed
    /// row from `replyBarCloseBackground`; a host button with its own `.buttonStyle` keeps it.
    ///
    /// - Since: 1.0.0
    public var overlayDim: Color

    // MARK: Fonts

    /// The channel name in the navigation bar.
    ///
    /// - Since: 1.0.0
    public var headerTitleFont: Font
    /// Text inside bubbles, and the labels of the long-press overlay's card rows.
    ///
    /// - Since: 1.0.0
    public var messageFont: Font
    /// The sender's name.
    ///
    /// - Since: 1.0.0
    public var senderNameFont: Font
    /// The quoted original above a reply's bubble. Its "replied to" line uses `senderNameFont`.
    ///
    /// - Since: 1.0.0
    public var replyQuoteFont: Font
    /// The time beside a bubble.
    ///
    /// - Since: 1.0.0
    public var timeFont: Font
    /// Centered system lines.
    ///
    /// - Since: 1.0.0
    public var systemMessageFont: Font
    /// The day above each day's first message. The time after it uses the same font at regular
    /// weight.
    ///
    /// - Since: 1.0.0
    public var dateSeparatorFont: Font
    /// The text and placeholder in the composer.
    ///
    /// - Since: 1.0.0
    public var composerFont: Font
    /// The reply bar's "Replying to" title. Its preview uses `replyQuoteFont`.
    ///
    /// - Since: 1.0.0
    public var replyBarTitleFont: Font
    /// The frozen channel banner.
    ///
    /// - Since: 1.0.0
    public var frozenBannerFont: Font

    /// Creates a theme. Anything left `nil` falls back to the light-appearance default.
    ///
    /// - Since: 1.0.0
    public init(
        background: Color? = nil,
        headerTitleText: Color? = nil,
        incomingBubbleBackground: Color? = nil,
        outgoingBubbleBackground: Color? = nil,
        incomingMessageText: Color? = nil,
        outgoingMessageText: Color? = nil,
        senderNameText: Color? = nil,
        replyQuoteText: Color? = nil,
        replyQuoteBorder: Color? = nil,
        timeText: Color? = nil,
        systemMessageText: Color? = nil,
        dateSeparatorBackground: Color? = nil,
        dateSeparatorText: Color? = nil,
        receiptSent: Color? = nil,
        receiptDelivered: Color? = nil,
        receiptRead: Color? = nil,
        avatarPlaceholderBackground: Color? = nil,
        avatarPlaceholderTint: Color? = nil,
        broadcastCoverBackground: Color? = nil,
        broadcastCoverTint: Color? = nil,
        accent: Color? = nil,
        placeholderTint: Color? = nil,
        fileIconBackground: Color? = nil,
        fileIconTint: Color? = nil,
        mediaPlaceholderTint: Color? = nil,
        mediaBadgeBackground: Color? = nil,
        mediaBadgeTint: Color? = nil,
        composerBackground: Color? = nil,
        composerFieldBackground: Color? = nil,
        composerText: Color? = nil,
        composerPlaceholderText: Color? = nil,
        composerButtonTint: Color? = nil,
        composerCursor: Color? = nil,
        replyBarCloseBackground: Color? = nil,
        composerDisabledTint: Color? = nil,
        sendingIndicatorTint: Color? = nil,
        failedIndicatorTint: Color? = nil,
        frozenBannerBackground: Color? = nil,
        frozenBannerText: Color? = nil,
        overlayDim: Color? = nil,
        headerTitleFont: Font? = nil,
        messageFont: Font? = nil,
        senderNameFont: Font? = nil,
        replyQuoteFont: Font? = nil,
        timeFont: Font? = nil,
        systemMessageFont: Font? = nil,
        dateSeparatorFont: Font? = nil,
        composerFont: Font? = nil,
        replyBarTitleFont: Font? = nil,
        frozenBannerFont: Font? = nil
    ) {
        self.background = background ?? ChatPalette.light.background
        self.headerTitleText = headerTitleText ?? ChatPalette.light.label
        self.incomingBubbleBackground = incomingBubbleBackground ?? ChatPalette.light.bubbleBackground
        self.outgoingBubbleBackground = outgoingBubbleBackground ?? ChatPalette.light.accent
        self.incomingMessageText = incomingMessageText ?? ChatPalette.light.label
        self.outgoingMessageText = outgoingMessageText ?? ChatPalette.onAccent
        self.senderNameText = senderNameText ?? ChatPalette.light.secondaryLabel
        self.replyQuoteText = replyQuoteText ?? ChatPalette.light.quoteText
        self.replyQuoteBorder = replyQuoteBorder ?? ChatPalette.light.quoteBorder
        self.timeText = timeText ?? ChatPalette.light.secondaryLabel
        self.systemMessageText = systemMessageText ?? ChatPalette.light.secondaryLabel
        self.dateSeparatorBackground = dateSeparatorBackground ?? .clear
        self.dateSeparatorText = dateSeparatorText ?? ChatPalette.light.secondaryLabel
        self.receiptSent = receiptSent ?? ChatPalette.light.tertiaryLabel
        self.receiptDelivered = receiptDelivered ?? ChatPalette.light.tertiaryLabel
        self.receiptRead = receiptRead ?? ChatPalette.light.accent
        self.avatarPlaceholderBackground = avatarPlaceholderBackground ?? ChatPalette.light.avatarBackground
        self.avatarPlaceholderTint = avatarPlaceholderTint ?? ChatPalette.onAccent
        self.broadcastCoverBackground = broadcastCoverBackground ?? ChatPalette.light.accent
        self.broadcastCoverTint = broadcastCoverTint ?? ChatPalette.onAccent
        self.accent = accent ?? ChatPalette.light.accent
        self.placeholderTint = placeholderTint ?? ChatPalette.light.secondaryLabel
        self.fileIconBackground = fileIconBackground ?? ChatPalette.light.background
        self.fileIconTint = fileIconTint ?? ChatPalette.light.accent
        self.mediaPlaceholderTint = mediaPlaceholderTint ?? ChatPalette.light.secondaryLabel
        self.mediaBadgeBackground = mediaBadgeBackground ?? ChatPalette.light.background
        self.mediaBadgeTint = mediaBadgeTint ?? ChatPalette.light.label
        self.composerBackground = composerBackground ?? .clear
        self.composerFieldBackground = composerFieldBackground ?? ChatPalette.light.secondaryBackground
        self.composerText = composerText ?? ChatPalette.light.label
        self.composerPlaceholderText = composerPlaceholderText ?? ChatPalette.light.placeholder
        self.composerButtonTint = composerButtonTint ?? ChatPalette.light.accent
        self.composerCursor = composerCursor ?? composerButtonTint ?? ChatPalette.light.cursor
        self.replyBarCloseBackground = replyBarCloseBackground ?? ChatPalette.light.closeFill
        self.composerDisabledTint = composerDisabledTint ?? ChatPalette.light.tertiaryLabel
        self.sendingIndicatorTint = sendingIndicatorTint ?? ChatPalette.light.accent
        self.failedIndicatorTint = failedIndicatorTint ?? ChatPalette.light.destructive
        self.frozenBannerBackground = frozenBannerBackground ?? ChatPalette.light.secondaryBackground
        self.frozenBannerText = frozenBannerText ?? ChatPalette.light.secondaryLabel
        self.overlayDim = overlayDim ?? ChatPalette.overlayDim
        self.headerTitleFont = headerTitleFont ?? ChatTypography.header
        self.messageFont = messageFont ?? ChatTypography.body
        self.senderNameFont = senderNameFont ?? ChatTypography.caption2
        self.replyQuoteFont = replyQuoteFont ?? ChatTypography.quote
        self.timeFont = timeFont ?? ChatTypography.caption2
        self.systemMessageFont = systemMessageFont ?? ChatTypography.caption
        self.dateSeparatorFont = dateSeparatorFont ?? ChatTypography.caption2.weight(.semibold)
        self.composerFont = composerFont ?? ChatTypography.composer
        self.replyBarTitleFont = replyBarTitleFont ?? ChatTypography.replyBarTitle
        self.frozenBannerFont = frozenBannerFont ?? ChatTypography.caption
    }
}

// MARK: - Built-in themes

public extension ChannelTheme {
    /// The light appearance.
    ///
    /// - Since: 1.0.0
    static let light = ChannelTheme()

    /// The dark appearance.
    ///
    /// - Since: 1.0.0
    static let dark = ChannelTheme(
        background: ChatPalette.dark.background,
        headerTitleText: ChatPalette.dark.label,
        incomingBubbleBackground: ChatPalette.dark.bubbleBackground,
        outgoingBubbleBackground: ChatPalette.dark.accent,
        incomingMessageText: ChatPalette.dark.label,
        outgoingMessageText: ChatPalette.onAccent,
        senderNameText: ChatPalette.dark.secondaryLabel,
        replyQuoteText: ChatPalette.dark.quoteText,
        replyQuoteBorder: ChatPalette.dark.quoteBorder,
        timeText: ChatPalette.dark.secondaryLabel,
        systemMessageText: ChatPalette.dark.secondaryLabel,
        dateSeparatorBackground: .clear,
        dateSeparatorText: ChatPalette.dark.secondaryLabel,
        receiptSent: ChatPalette.dark.tertiaryLabel,
        receiptDelivered: ChatPalette.dark.tertiaryLabel,
        receiptRead: ChatPalette.dark.accent,
        avatarPlaceholderBackground: ChatPalette.dark.avatarBackground,
        avatarPlaceholderTint: ChatPalette.onAccent,
        broadcastCoverBackground: ChatPalette.dark.accent,
        broadcastCoverTint: ChatPalette.onAccent,
        accent: ChatPalette.dark.accent,
        placeholderTint: ChatPalette.dark.secondaryLabel,
        fileIconBackground: ChatPalette.dark.background,
        fileIconTint: ChatPalette.dark.accent,
        mediaPlaceholderTint: ChatPalette.dark.secondaryLabel,
        mediaBadgeBackground: ChatPalette.dark.background,
        mediaBadgeTint: ChatPalette.dark.label,
        composerBackground: .clear,
        composerFieldBackground: ChatPalette.dark.secondaryBackground,
        composerText: ChatPalette.dark.label,
        composerPlaceholderText: ChatPalette.dark.placeholder,
        composerButtonTint: ChatPalette.dark.accent,
        composerCursor: ChatPalette.dark.cursor,
        replyBarCloseBackground: ChatPalette.dark.closeFill,
        composerDisabledTint: ChatPalette.dark.tertiaryLabel,
        sendingIndicatorTint: ChatPalette.dark.accent,
        failedIndicatorTint: ChatPalette.dark.destructive,
        frozenBannerBackground: ChatPalette.dark.secondaryBackground,
        frozenBannerText: ChatPalette.dark.secondaryLabel,
        overlayDim: ChatPalette.overlayDim
    )

    /// Follows the system appearance. This is the default.
    ///
    /// - Since: 1.0.0
    static let adaptive = ChannelTheme(
        background: pair(\.background),
        headerTitleText: pair(\.headerTitleText),
        incomingBubbleBackground: pair(\.incomingBubbleBackground),
        outgoingBubbleBackground: pair(\.outgoingBubbleBackground),
        incomingMessageText: pair(\.incomingMessageText),
        outgoingMessageText: pair(\.outgoingMessageText),
        senderNameText: pair(\.senderNameText),
        replyQuoteText: pair(\.replyQuoteText),
        replyQuoteBorder: pair(\.replyQuoteBorder),
        timeText: pair(\.timeText),
        systemMessageText: pair(\.systemMessageText),
        dateSeparatorBackground: pair(\.dateSeparatorBackground),
        dateSeparatorText: pair(\.dateSeparatorText),
        receiptSent: pair(\.receiptSent),
        receiptDelivered: pair(\.receiptDelivered),
        receiptRead: pair(\.receiptRead),
        avatarPlaceholderBackground: pair(\.avatarPlaceholderBackground),
        avatarPlaceholderTint: pair(\.avatarPlaceholderTint),
        broadcastCoverBackground: pair(\.broadcastCoverBackground),
        broadcastCoverTint: pair(\.broadcastCoverTint),
        accent: pair(\.accent),
        placeholderTint: pair(\.placeholderTint),
        fileIconBackground: pair(\.fileIconBackground),
        fileIconTint: pair(\.fileIconTint),
        mediaPlaceholderTint: pair(\.mediaPlaceholderTint),
        mediaBadgeBackground: pair(\.mediaBadgeBackground),
        mediaBadgeTint: pair(\.mediaBadgeTint),
        composerBackground: pair(\.composerBackground),
        composerFieldBackground: pair(\.composerFieldBackground),
        composerText: pair(\.composerText),
        composerPlaceholderText: pair(\.composerPlaceholderText),
        composerButtonTint: pair(\.composerButtonTint),
        composerCursor: pair(\.composerCursor),
        replyBarCloseBackground: pair(\.replyBarCloseBackground),
        composerDisabledTint: pair(\.composerDisabledTint),
        sendingIndicatorTint: pair(\.sendingIndicatorTint),
        failedIndicatorTint: pair(\.failedIndicatorTint),
        frozenBannerBackground: pair(\.frozenBannerBackground),
        frozenBannerText: pair(\.frozenBannerText),
        overlayDim: pair(\.overlayDim)
    )

    private static func pair(_ keyPath: KeyPath<ChannelTheme, Color>) -> Color {
        ChatPalette.adaptive(light: light[keyPath: keyPath], dark: dark[keyPath: keyPath])
    }
}
