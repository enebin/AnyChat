import Foundation
import AnyChatUI

/// Who liked a message, kept in `ChatMessage.attributes`.
nonisolated struct Likes: Hashable, Sendable {
    var userIDs: [String]
}

/// An in-memory backend. Friends type, answer, and like your messages a moment after you send.
@MainActor
final class PrismBackend: ChatBackend {
    static let me = ChatSender(id: "me", name: "You")

    let currentUserID: String? = PrismBackend.me.id

    private var channels: [ChatChannel]
    private var messages: [String: [ChatMessage]]
    private var replyCursor: [String: Int] = [:]
    private var listObservers: [UUID: AsyncStream<[ChatChannel]>.Continuation] = [:]
    private var threadObservers: [String: [UUID: AsyncStream<[ChatMessage]>.Continuation]] = [:]

    init(now: Date = Date()) {
        let threads = PrismSampleData.threads(now: now)
        channels = threads.map(\.channel)
        messages = Dictionary(uniqueKeysWithValues: threads.map { ($0.channel.id, $0.messages) })
    }

    func makeChannelListRepository() -> any ChannelListRepository {
        PrismChannelListRepository(backend: self)
    }

    func makeChannelRepository(channelID: String) -> any ChannelRepository {
        PrismChannelRepository(backend: self, channelID: channelID)
    }

    var sortedChannels: [ChatChannel] {
        channels.sorted { lastActivity($0) > lastActivity($1) }
    }

    func channel(with person: ChatSender) -> ChatChannel {
        if let existing = channels.first(where: { $0.members.count == 2 && $0.members.contains(person) }) {
            return existing
        }
        let channel = ChatChannel(
            id: "dm-\(person.id)",
            name: person.name,
            createdAt: Date(),
            members: [Self.me, person],
            canLeave: true
        )
        channels.append(channel)
        messages[channel.id] = []
        publishChannels()
        return channel
    }

    func toggleLike(messageID: String, channelID: String) {
        updateMessage(messageID, channelID: channelID) { message in
            var likes = message.attributes[Likes.self] ?? Likes(userIDs: [])
            if let index = likes.userIDs.firstIndex(of: Self.me.id) {
                likes.userIDs.remove(at: index)
            } else {
                likes.userIDs.append(Self.me.id)
            }
            message.attributes[Likes.self] = likes.userIDs.isEmpty ? nil : likes
        }
    }
}

// MARK: - Observation

extension PrismBackend {
    func observeChannels() -> (UUID, AsyncStream<[ChatChannel]>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[ChatChannel]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        listObservers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listObservers[id] = nil }
        }
        return (id, stream)
    }

    func stopObservingChannels(_ id: UUID) {
        listObservers.removeValue(forKey: id)?.finish()
    }

    func observeMessages(channelID: String) -> (UUID, AsyncStream<[ChatMessage]>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        threadObservers[channelID, default: [:]][id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.threadObservers[channelID]?[id] = nil }
        }
        updateChannel(channelID) { $0.unreadMessageCount = 0 }
        return (id, stream)
    }

    func stopObservingMessages(_ id: UUID, channelID: String) {
        threadObservers[channelID]?.removeValue(forKey: id)?.finish()
    }

    func messages(channelID: String) throws -> [ChatMessage] {
        guard let messages = messages[channelID] else {
            throw ChannelRepositoryError.channelNotFound
        }
        return messages
    }

    private func publishChannels() {
        let snapshot = sortedChannels
        listObservers.values.forEach { $0.yield(snapshot) }
    }

    private func publishMessages(channelID: String) {
        guard let snapshot = messages[channelID] else {
            return
        }
        threadObservers[channelID]?.values.forEach { $0.yield(snapshot) }
    }

    private func isOpen(_ channelID: String) -> Bool {
        !(threadObservers[channelID]?.isEmpty ?? true)
    }
}

// MARK: - Sending

extension PrismBackend {
    func send(_ message: ChatMessage, channelID: String) {
        var message = message
        message.sendingStatus = .pending
        messages[channelID, default: []].append(message)
        publishMessages(channelID: channelID)

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            finishSending(message.id, channelID: channelID)
        }
    }

    func resend(messageID: String, channelID: String) {
        updateMessage(messageID, channelID: channelID) { $0.sendingStatus = .pending }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            finishSending(messageID, channelID: channelID)
        }
    }

    func removeFailed(messageID: String, channelID: String) {
        messages[channelID]?.removeAll { $0.id == messageID && $0.sendingStatus == .failed }
        publishMessages(channelID: channelID)
    }

    private func finishSending(_ messageID: String, channelID: String) {
        updateMessage(messageID, channelID: channelID) {
            $0.sendingStatus = nil
            $0.receipt = .sent
        }
        if let sent = messages[channelID]?.first(where: { $0.id == messageID }) {
            updateChannel(channelID) { $0.lastMessage = sent }
        }
        scheduleReply(to: messageID, channelID: channelID)
    }

    private func scheduleReply(to messageID: String, channelID: String) {
        guard let friend = channels.first(where: { $0.id == channelID })?.members.first(where: { $0.id != Self.me.id }) else {
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            markRead(channelID: channelID)
            updateMessage(messageID, channelID: channelID) {
                $0.attributes[Likes.self] = Likes(userIDs: [friend.id])
            }
            updateChannel(channelID) { $0.typingUsers = [friend] }

            try? await Task.sleep(for: .seconds(2))
            let cursor = replyCursor[channelID, default: 0]
            replyCursor[channelID] = cursor + 1
            let replies = PrismSampleData.replies
            let reply = ChatMessage(
                id: UUID().uuidString,
                sender: friend,
                createdAt: Date(),
                content: .text(replies[cursor % replies.count])
            )
            messages[channelID, default: []].append(reply)
            publishMessages(channelID: channelID)
            let opened = isOpen(channelID)
            updateChannel(channelID) {
                $0.typingUsers = []
                $0.lastMessage = reply
                if !opened {
                    $0.unreadMessageCount = ($0.unreadMessageCount ?? 0) + 1
                }
            }
        }
    }

    private func markRead(channelID: String) {
        guard var thread = messages[channelID] else {
            return
        }
        for index in thread.indices where thread[index].sender?.id == Self.me.id && thread[index].receipt != nil {
            thread[index].receipt = .read
        }
        messages[channelID] = thread
        publishMessages(channelID: channelID)
    }
}

// MARK: - Mutation

private extension PrismBackend {
    func updateMessage(_ id: String, channelID: String, _ change: (inout ChatMessage) -> Void) {
        guard let index = messages[channelID]?.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&messages[channelID]![index])
        publishMessages(channelID: channelID)
        if channels.first(where: { $0.id == channelID })?.lastMessage?.id == id, let message = messages[channelID]?[index] {
            updateChannel(channelID) { $0.lastMessage = message }
        }
    }

    func updateChannel(_ id: String, _ change: (inout ChatChannel) -> Void) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&channels[index])
        publishChannels()
    }

    func lastActivity(_ channel: ChatChannel) -> Date {
        channel.lastMessage?.createdAt ?? channel.createdAt
    }
}

// MARK: - Leaving and muting

extension PrismBackend {
    func leave(channelID: String) throws {
        guard channels.contains(where: { $0.id == channelID }) else {
            throw ChannelListRepositoryError.channelNotFound
        }
        channels.removeAll { $0.id == channelID }
        messages[channelID] = nil
        publishChannels()
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) throws {
        guard channels.contains(where: { $0.id == channelID }) else {
            throw ChannelListRepositoryError.channelNotFound
        }
        updateChannel(channelID) { $0.notificationLevel = level }
    }
}
