import Foundation
import AnyChatCore

/// Builds messages for channel screen tests, so each test spells out only what it cares about.
enum MessageFixtures {
    /// 2023-11-14 22:13:20 UTC.
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func message(
        _ id: String,
        from senderID: String? = "u1",
        _ content: ChatMessage.Content = .text("Hello"),
        at createdAt: Date = start,
        receipt: ChatMessage.Receipt? = nil,
        sendingStatus: ChatMessage.SendingStatus? = nil
    ) -> ChatMessage {
        var message = ChatMessage(
            id: id,
            sender: senderID.map { ChatSender(id: $0, name: $0.capitalized) },
            createdAt: createdAt,
            content: content,
            receipt: receipt
        )
        message.sendingStatus = sendingStatus
        return message
    }

    static func page(_ messages: [ChatMessage], hasPrevious: Bool = false) -> MessagePage {
        MessagePage(messages: messages, hasPrevious: hasPrevious)
    }
}
