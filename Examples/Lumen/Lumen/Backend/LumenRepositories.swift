import Foundation
import AnyChatUI

@MainActor
final class LumenChannelListRepository: ChannelListRepository {
    private let backend: LumenBackend
    private var observation: UUID?

    init(backend: LumenBackend) {
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
        try backend.delete(channelID: channelID)
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {
        throw ChannelListRepositoryError.channelNotFound
    }

    func stopObserving() {
        if let observation {
            backend.stopObservingChannels(observation)
        }
        observation = nil
    }
}

@MainActor
final class LumenChannelRepository: ChannelRepository {
    private let backend: LumenBackend
    private let channelID: String
    private var observation: UUID?

    init(backend: LumenBackend, channelID: String) {
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
        backend.send(text: text, channelID: channelID)
    }

    /// There is no upload, so the sent message points at the picked files' local copies.
    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: LumenBackend.me,
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
