import AnyChatCore

/// What the default quote above a reply's bubble shows of the original.
nonisolated struct ReplyQuote: Hashable {
    static let unavailableText = "Original message unavailable"
    /// For an original this screen cannot describe, such as an unsupported custom message.
    static let fallbackText = "Message"

    /// The "replied to" line, such as "You replied to Alice" or "Replied to you".
    let line: String
    /// The original's text, or a word for its attachment, such as "Photo".
    let text: String
    /// The original's first image, GIF, or video when it has no text, drawn instead of `text`.
    let thumbnail: ChatAttachment?
    let isUnavailable: Bool

    init(_ reference: ChatMessage.ReplyReference, replyIsMine: Bool, currentUserID: String?) {
        isUnavailable = reference.isUnavailable
        line = Self.line(for: reference, replyIsMine: replyIsMine, currentUserID: currentUserID)
        guard !reference.isUnavailable else {
            text = Self.unavailableText
            thumbnail = nil
            return
        }
        text = Self.text(of: reference.content, attachments: reference.attachments)
        let hasText = if case let .text(body) = reference.content { !body.isEmpty } else { false }
        thumbnail = hasText ? nil : reference.attachments.first { $0.isMedia }
    }

    /// The reply's own sender is named by the row's sender name, so another person's reply says
    /// only whom it answers.
    private static func line(for reference: ChatMessage.ReplyReference, replyIsMine: Bool, currentUserID: String?) -> String {
        let originalIsMine = reference.sender?.id != nil && reference.sender?.id == currentUserID
        let originalName = reference.sender.map(name(of:))
        switch (replyIsMine, reference.isUnavailable, originalIsMine, originalName) {
        case (true, true, _, _), (true, false, false, nil):
            return "You replied"
        case (true, false, true, _):
            return "You replied to yourself"
        case let (true, false, false, name?):
            return "You replied to \(name)"
        case (false, true, _, _), (false, false, false, nil):
            return "Replied"
        case (false, false, true, _):
            return "Replied to you"
        case let (false, false, false, name?):
            return "Replied to \(name)"
        }
    }
}

nonisolated extension ReplyQuote {
    /// The original's text, or the word for its attachment, shared with the reply bar.
    static func text(of content: ChatMessage.Content, attachments: [ChatAttachment]) -> String {
        let preview = MessagePreviewFormatter.preview(of: content, attachments: attachments).text
        return preview.isEmpty ? fallbackText : preview
    }

    static func name(of sender: ChatSender) -> String {
        sender.name ?? sender.id
    }
}

/// What the default reply bar shows of the message being answered.
nonisolated struct ReplyBarText: Hashable {
    let title: String
    let preview: String

    init(_ message: ChatMessage, currentUserID: String?) {
        if MessageRowState.isMine(message, currentUserID: currentUserID) {
            title = "Replying to yourself"
        } else if let sender = message.sender {
            title = "Replying to \(ReplyQuote.name(of: sender))"
        } else {
            title = "Replying"
        }
        preview = ReplyQuote.text(of: message.content, attachments: message.attachments)
    }
}
