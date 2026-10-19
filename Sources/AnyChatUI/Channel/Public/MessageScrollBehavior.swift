/// How the channel screen's message list moves when the user sends a message.
///
/// Set it with `ChannelView.messageScrollBehavior(_:)`:
///
/// ```swift
/// ChannelView(channel: channel)
///     .messageScrollBehavior(.questionToTop)
/// ```
///
/// - Since: 1.0.0
nonisolated public enum MessageScrollBehavior: Sendable, Hashable {
    /// The list scrolls to the newest message and follows new and growing messages while it stays
    /// at the bottom, as in a messenger. This is the default.
    ///
    /// - Since: 1.0.0
    case followsLatest

    /// The message the user sends moves to the top of the list, and the reply fills the space
    /// below it, as in an AI chat.
    ///
    /// The list adds blank space below the messages so the sent message can reach the top even in
    /// a short channel. The space shrinks as the reply grows and is gone once the reply reaches the
    /// bottom of the screen. The list does not follow the reply past that point; the
    /// jump-to-latest button shows instead. The "question" is any text or attachment the user
    /// sends from the composer, including `ComposerContext.send(text:)`.
    ///
    /// - Since: 1.0.0
    case questionToTop
}
