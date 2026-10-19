import AnyChatCore

/// Builds the one-line message preview on a channel row, and the words a reply's quote uses for
/// an original's content.
nonisolated enum MessagePreviewFormatter {
    static let photo = "Photo"
    static let gif = "GIF"
    static let video = "Video"
    static let audio = "Audio"
    static let voice = "Voice message"
    static let file = "File"
    static let multipleFiles = "Photo"
    static let unnamedTypingMember = "Member"

    /// How the preview should be truncated when it does not fit.
    enum Truncation: Hashable {
        case tail
        case middle
    }

    struct Preview: Hashable {
        var text: String
        var truncation: Truncation
    }

    /// Returns the typing indicator when someone is typing, otherwise the last message preview.
    static func preview(for channel: ChatChannel, options: ChannelListOptions) -> Preview {
        if options.isTypingIndicatorEnabled, !channel.typingUsers.isEmpty {
            return Preview(text: typingText(for: channel.typingUsers), truncation: .tail)
        }

        return lastMessagePreview(for: channel.lastMessage)
    }

    static func typingText(for users: [ChatSender]) -> String {
        func name(_ user: ChatSender) -> String {
            user.name ?? unnamedTypingMember
        }

        switch users.count {
        case 1:
            return "\(name(users[0])) is typing..."
        case 2:
            return "\(name(users[0])) and \(name(users[1])) are typing..."
        default:
            return "Several people are typing..."
        }
    }

    static func lastMessagePreview(for message: ChatMessage?) -> Preview {
        guard let message else {
            return Preview(text: "", truncation: .tail)
        }
        return preview(of: message.content, attachments: message.attachments)
    }

    static func preview(of content: ChatMessage.Content, attachments: [ChatAttachment]) -> Preview {
        switch content {
        case let .text(text):
            if !text.isEmpty {
                Preview(text: text, truncation: .tail)
            } else if let attachment = attachments.first {
                Preview(text: attachments.count == 1 ? Self.text(for: attachment.kind) : multipleFiles, truncation: .middle)
            } else {
                Preview(text: "", truncation: .tail)
            }
        case let .file(kind):
            Preview(text: text(for: kind), truncation: .middle)
        case .files:
            Preview(text: multipleFiles, truncation: .middle)
        case let .system(text):
            Preview(text: text, truncation: .middle)
        case .unsupported:
            Preview(text: "", truncation: .tail)
        }
    }

    static func text(for kind: ChatMessage.FileKind) -> String {
        switch kind {
        case .image: photo
        case .gif: gif
        case .video: video
        case .audio: audio
        case .voice: voice
        case .other: file
        }
    }
}
