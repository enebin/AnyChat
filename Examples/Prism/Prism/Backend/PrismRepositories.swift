import Foundation
import AnyChatUI

@MainActor
final class PrismChannelListRepository: ChannelListRepository {
    private let backend: PrismBackend
    private var observation: UUID?

    init(backend: PrismBackend) {
        self.backend = backend
    }

    func startObserving() -> AsyncStream<[ChatChannel]> {
        stopObserving()
        let (id, stream) = backend.observeChannels()
        observation = id
        return stream
    }

    func loadMore() async throws -> ChannelListPage {
        guard observation != nil else {
            throw ChannelListRepositoryError.notObserving
        }
        return ChannelListPage(channels: backend.sortedChannels, hasNext: false)
    }

    func leave(channelID: String) async throws {
        try backend.leave(channelID: channelID)
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {
        try backend.setNotificationLevel(level, channelID: channelID)
    }

    func stopObserving() {
        if let observation {
            backend.stopObservingChannels(observation)
        }
        observation = nil
    }
}

@MainActor
final class PrismChannelRepository: ChannelRepository {
    private let backend: PrismBackend
    private let channelID: String
    private var observation: UUID?

    init(backend: PrismBackend, channelID: String) {
        self.backend = backend
        self.channelID = channelID
    }

    func startObserving() -> AsyncStream<[ChatMessage]> {
        stopObserving()
        let (id, stream) = backend.observeMessages(channelID: channelID)
        observation = id
        return stream
    }

    func loadPrevious() async throws -> MessagePage {
        guard observation != nil else {
            throw ChannelRepositoryError.notObserving
        }
        return MessagePage(messages: try backend.messages(channelID: channelID), hasPrevious: false)
    }

    func sendMessage(text: String, replyTo: String?) {
        backend.send(
            ChatMessage(id: UUID().uuidString, sender: PrismBackend.me, createdAt: Date(), content: .text(text)),
            channelID: channelID
        )
    }

    /// There is no upload, so the sent message points at the picked files' local copies.
    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: PrismBackend.me,
            createdAt: Date(),
            attachments: attachments.map {
                ChatAttachment(id: UUID().uuidString, kind: $0.kind, url: $0.fileURL, fileName: $0.fileName)
            }
        )
        backend.send(message, channelID: channelID)
    }

    func resendMessage(id: String) {
        backend.resend(messageID: id, channelID: channelID)
    }

    func removeFailedMessage(id: String) {
        backend.removeFailed(messageID: id, channelID: channelID)
    }

    func stopObserving() {
        if let observation {
            backend.stopObservingMessages(observation, channelID: channelID)
        }
        observation = nil
    }
}
