extension ChatMessage {
    /// What a reply shows of the message it answers.
    ///
    /// A summary rather than the original message: it carries what a quote draws, so a quote can
    /// be drawn even when the original is on a page the screen has not read, and a receipt or
    /// attribute change on the original does not redraw every reply to it. `content` and
    /// `attachments` mean what they mean on `ChatMessage`; for a custom message, use its `content`
    /// fallback. When the original is edited or deleted, send the reply again with the same `id`
    /// and an updated reference.
    ///
    /// - Since: 1.0.0
    public struct ReplyReference: Sendable, Hashable {
        /// The `id` of the message being answered. It stays when the original becomes unavailable.
        ///
        /// - Since: 1.0.0
        public var messageID: String

        /// The original's sender, or `nil` when the backend wrote it or it is unavailable.
        ///
        /// - Since: 1.0.0
        public var sender: ChatSender?

        /// - Since: 1.0.0
        public var content: Content

        /// - Since: 1.0.0
        public var attachments: [ChatAttachment]

        /// The original can no longer be shown, because it was deleted or the current user cannot
        /// see it. Leave `content` and `attachments` empty; the quote then shows its unavailable
        /// text.
        ///
        /// - Since: 1.0.0
        public var isUnavailable: Bool

        /// Creates a reference to an original that can be shown.
        ///
        /// - Since: 1.0.0
        public init(messageID: String, sender: ChatSender? = nil, content: Content, attachments: [ChatAttachment] = []) {
            self.messageID = messageID
            self.sender = sender
            self.content = content
            self.attachments = attachments
            self.isUnavailable = false
        }

        /// Creates a reference to an original that was deleted or that the current user cannot see.
        ///
        /// - Since: 1.0.0
        public static func unavailable(messageID: String) -> ReplyReference {
            var reference = ReplyReference(messageID: messageID, content: .text(""))
            reference.isUnavailable = true
            return reference
        }
    }
}
