import Foundation
import AnyChatCore

/// Builds domain values for tests, so each test spells out only the fields it cares about.
enum ChannelFixtures {
    static let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    static func channel(
        id: String = "channel_1",
        _ configure: (inout ChatChannel) -> Void = { _ in }
    ) -> ChatChannel {
        var channel = ChatChannel(id: id, createdAt: createdAt)
        configure(&channel)
        return channel
    }

    static func message(
        _ content: ChatMessage.Content = .text("Hello"),
        senderID: String? = "u1",
        createdAt: Date = createdAt,
        receipt: ChatMessage.Receipt? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: "message_1",
            sender: senderID.map { ChatSender(id: $0) },
            createdAt: createdAt,
            content: content,
            receipt: receipt
        )
    }
}
