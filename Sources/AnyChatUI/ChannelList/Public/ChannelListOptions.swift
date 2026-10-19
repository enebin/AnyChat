/// Feature switches for the channel list.
///
/// Every switch is off by default.
nonisolated public struct ChannelListOptions: Sendable, Equatable {
    /// Shows "… is typing…" in place of the message preview while someone is typing.
    ///
    /// - Since: 1.0.0
    public var isTypingIndicatorEnabled: Bool

    /// Shows the sent / delivered / read icon next to the timestamp for messages you sent.
    ///
    /// - Since: 1.0.0
    public var isMessageReceiptStatusEnabled: Bool

    /// Shows an "@" mark on rows with unread mentions.
    ///
    /// - Since: 1.0.0
    public var isMentionBadgeEnabled: Bool

    /// Creates options.
    ///
    /// - Since: 1.0.0
    public init(
        isTypingIndicatorEnabled: Bool = false,
        isMessageReceiptStatusEnabled: Bool = false,
        isMentionBadgeEnabled: Bool = false
    ) {
        self.isTypingIndicatorEnabled = isTypingIndicatorEnabled
        self.isMessageReceiptStatusEnabled = isMessageReceiptStatusEnabled
        self.isMentionBadgeEnabled = isMentionBadgeEnabled
    }
}
