import Foundation
import Observation
import AnyChatUI

/// Marks an assistant answer and where its generation is. Kept in `ChatMessage.customContent`, so the
/// channel screen draws answers with their own row while the text stays in `content` for previews.
nonisolated struct Answer: Hashable, Sendable {
    enum Phase: Hashable, Sendable {
        case thinking
        case streaming
        case done
        case stopped
    }

    var phase: Phase
    var mode: ToolMode? = nil

    var isGenerating: Bool { phase == .thinking || phase == .streaming }
}

/// The user's rating of an answer, kept in `ChatMessage.attributes`.
nonisolated enum Feedback: Hashable, Sendable {
    case good
    case bad
}

/// A tool picked from the attach sheet. It changes which canned reply comes back and how long the
/// assistant thinks first.
nonisolated enum ToolMode: String, CaseIterable, Hashable, Sendable {
    case createImage
    case thinkLonger
    case webSearch

    var title: String {
        switch self {
        case .createImage: "Create image"
        case .thinkLonger: "Think longer"
        case .webSearch: "Web search"
        }
    }

    var subtitle: String {
        switch self {
        case .createImage: "Turn an idea into a picture"
        case .thinkLonger: "Better answers for hard questions"
        case .webSearch: "Find recent news and info"
        }
    }

    var systemImage: String {
        switch self {
        case .createImage: "paintbrush.pointed"
        case .thinkLonger: "lightbulb"
        case .webSearch: "globe"
        }
    }
}

/// An in-memory backend. Every message gets a canned answer that streams in a few words at a time.
@MainActor
@Observable
final class LumenBackend: ChatBackend {
    nonisolated static let me = ChatSender(id: "me", name: "Jamie Park")
    nonisolated static let assistant = ChatSender(id: "lumen", name: "Lumen")

    let currentUserID: String? = LumenBackend.me.id

    /// The tool the composer will send with. One chat is on screen at a time, so one value is enough.
    var selectedMode: ToolMode?

    private(set) var generatingChannelIDs: Set<String> = []

    @ObservationIgnored private var channels: [ChatChannel]
    @ObservationIgnored private var messages: [String: [ChatMessage]]
    @ObservationIgnored private var generations: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var listObservers: [UUID: AsyncStream<[ChatChannel]>.Continuation] = [:]
    @ObservationIgnored private var threadObservers: [String: [UUID: AsyncStream<[ChatMessage]>.Continuation]] = [:]

    private let wordDelay: Duration

    init(now: Date = Date(), wordDelay: Duration = .milliseconds(35)) {
        let chats = LumenReplies.history(now: now)
        channels = chats.map(\.channel)
        messages = Dictionary(uniqueKeysWithValues: chats.map { ($0.channel.id, $0.messages) })
        self.wordDelay = wordDelay
    }

    func makeChannelListRepository() -> any ChannelListRepository {
        LumenChannelListRepository(backend: self)
    }

    func makeChannelRepository(channelID: String) -> any ChannelRepository {
        LumenChannelRepository(backend: self, channelID: channelID)
    }

    /// Chats with at least one message, newest first. The new chat stays out of the drawer until then.
    var sortedChannels: [ChatChannel] {
        channels
            .filter { messages[$0.id]?.isEmpty == false }
            .sorted { lastActivity($0) > lastActivity($1) }
    }

    func isGenerating(channelID: String) -> Bool {
        generatingChannelIDs.contains(channelID)
    }

    /// The chat without messages, made if there is none, so opening a new chat twice reuses it. Its
    /// first message names it.
    func newChat() -> ChatChannel {
        if let empty = channels.first(where: { messages[$0.id]?.isEmpty == true }) {
            return empty
        }
        let channel = ChatChannel(
            id: UUID().uuidString,
            createdAt: Date(),
            members: [Self.me, Self.assistant],
            canLeave: true
        )
        channels.append(channel)
        messages[channel.id] = []
        return channel
    }

    func channel(id: String) -> ChatChannel? {
        channels.first { $0.id == id }
    }
}

// MARK: - Observation

extension LumenBackend {
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
}

// MARK: - Sending

extension LumenBackend {
    func send(text: String, channelID: String) {
        let message = ChatMessage(id: UUID().uuidString, sender: Self.me, createdAt: Date(), content: .text(text))
        send(message, channelID: channelID)
    }

    func send(_ message: ChatMessage, channelID: String) {
        var message = message
        message.sendingStatus = .pending
        let isFirst = messages[channelID]?.isEmpty == true
        messages[channelID, default: []].append(message)
        publishMessages(channelID: channelID)
        if isFirst {
            updateChannel(channelID) { $0.name = LumenReplies.title(for: message.plainText) }
        }

        let mode = selectedMode
        selectedMode = nil
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            finishSending(message.id, channelID: channelID, mode: mode)
        }
    }

    func resend(messageID: String, channelID: String) {
        updateMessage(messageID, channelID: channelID) { $0.sendingStatus = .pending }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            finishSending(messageID, channelID: channelID, mode: nil)
        }
    }

    func removeFailed(messageID: String, channelID: String) {
        messages[channelID]?.removeAll { $0.id == messageID && $0.sendingStatus == .failed }
        publishMessages(channelID: channelID)
    }

    private func finishSending(_ messageID: String, channelID: String, mode: ToolMode?) {
        updateMessage(messageID, channelID: channelID) { $0.sendingStatus = nil }
        guard let question = messages[channelID]?.first(where: { $0.id == messageID }) else {
            return
        }
        // The composer blocks text while an answer generates, but attachments still arrive. One
        // generation per chat keeps the stop button tied to the answer that is running.
        stop(channelID: channelID)
        let answerID = UUID().uuidString
        let answer = ChatMessage(
            id: answerID,
            sender: Self.assistant,
            createdAt: Date(),
            content: .text(""),
            customContent: Answer(phase: .thinking, mode: mode)
        )
        messages[channelID, default: []].append(answer)
        publishMessages(channelID: channelID)
        generate(answerID, channelID: channelID, reply: LumenReplies.reply(to: question, mode: mode), mode: mode)
    }
}

// MARK: - Generation

extension LumenBackend {
    /// Ends the running answer where it is. The text so far stays.
    func stop(channelID: String) {
        guard let task = generations.removeValue(forKey: channelID) else {
            return
        }
        task.cancel()
        generatingChannelIDs.remove(channelID)
        guard let answer = messages[channelID]?.last(where: { $0.customContent?.value(as: Answer.self)?.isGenerating == true }) else {
            return
        }
        updateMessage(answer.id, channelID: channelID) {
            $0.customContent = ChatMessage.CustomContent(Answer(phase: .stopped, mode: $0.answer?.mode))
        }
    }

    /// Writes the answer again from the start, in place.
    func regenerate(messageID: String, channelID: String) {
        guard !isGenerating(channelID: channelID),
              let thread = messages[channelID],
              let index = thread.firstIndex(where: { $0.id == messageID }),
              let question = thread[..<index].last(where: { $0.sender?.id == Self.me.id }) else {
            return
        }
        let mode = thread[index].answer?.mode
        updateMessage(messageID, channelID: channelID) {
            $0.content = .text("")
            $0.attachments = []
            $0.attributes[Feedback.self] = nil
            $0.customContent = ChatMessage.CustomContent(Answer(phase: .thinking, mode: mode))
        }
        let reply = LumenReplies.reply(to: question, mode: mode, variant: 1)
        generate(messageID, channelID: channelID, reply: reply, mode: mode)
    }

    func setFeedback(_ feedback: Feedback?, messageID: String, channelID: String) {
        updateMessage(messageID, channelID: channelID) { $0.attributes[Feedback.self] = feedback }
    }

    private func generate(_ answerID: String, channelID: String, reply: LumenReply, mode: ToolMode?) {
        generatingChannelIDs.insert(channelID)
        let thinking: Duration = mode == .thinkLonger ? .seconds(3) : .milliseconds(900)
        let wordDelay = wordDelay
        generations[channelID] = Task {
            do {
                try await Task.sleep(for: thinking)
                var text = ""
                for word in LumenReplies.words(of: reply.text) {
                    guard !Task.isCancelled else { return }
                    text += word
                    updateMessage(answerID, channelID: channelID) {
                        $0.content = .text(text)
                        $0.attachments = reply.attachments
                        $0.customContent = ChatMessage.CustomContent(Answer(phase: .streaming, mode: mode))
                    }
                    try await Task.sleep(for: wordDelay)
                }
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            updateMessage(answerID, channelID: channelID) {
                $0.customContent = ChatMessage.CustomContent(Answer(phase: .done, mode: mode))
            }
            generations[channelID] = nil
            generatingChannelIDs.remove(channelID)
        }
    }
}

// MARK: - Mutation

private extension LumenBackend {
    func updateMessage(_ id: String, channelID: String, _ change: (inout ChatMessage) -> Void) {
        guard let index = messages[channelID]?.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&messages[channelID]![index])
        publishMessages(channelID: channelID)
        // Updating the list on every streamed word would redraw the drawer for nothing.
        let message = messages[channelID]![index]
        if message.id == messages[channelID]?.last?.id, message.sendingStatus == nil, message.answer?.isGenerating != true {
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

// MARK: - Deleting

extension LumenBackend {
    func delete(channelID: String) throws {
        guard channels.contains(where: { $0.id == channelID }) else {
            throw ChannelListRepositoryError.channelNotFound
        }
        stop(channelID: channelID)
        channels.removeAll { $0.id == channelID }
        messages[channelID] = nil
        publishChannels()
    }
}

nonisolated extension ChatMessage {
    var answer: Answer? { customContent?.value(as: Answer.self) }

    var plainText: String {
        if case .text(let text) = content { text } else { "" }
    }
}
