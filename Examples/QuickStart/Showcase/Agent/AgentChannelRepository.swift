import Foundation
import AnyChatUI

/// Plays a scripted agent run. Each step is a message whose custom value changes in place, and
/// some steps are removed again, the way an agent backend reports progress.
///
/// The run is not tied to an observation: like a server-side agent it keeps going while the
/// screen re-observes, and the next snapshot carries where it got to.
@MainActor
final class AgentChannelRepository: ChannelRepository {
    private static let wordInterval: Duration = .milliseconds(60)
    private static let toolInterval: Duration = .milliseconds(700)
    private static let thinkingDuration: Duration = .milliseconds(1_500)
    private static let sendDelay: Duration = .milliseconds(500)

    private var messages: [ChatMessage]
    private var continuation: AsyncStream<[ChatMessage]>.Continuation?
    private var run: Task<Void, Never>?

    init() {
        messages = [
            ChatMessage(id: "prompt", sender: SampleData.me, createdAt: Date(), content: .text(Script.prompt))
        ]
    }

    func startObserving() -> AsyncStream<[ChatMessage]> {
        stopObserving()
        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        return stream
    }

    func loadPrevious() async throws -> MessagePage {
        guard let continuation else {
            throw ChannelRepositoryError.notObserving
        }
        continuation.yield(messages)
        if run == nil {
            startRun()
        }
        return MessagePage(messages: messages, hasPrevious: false)
    }

    func sendMessage(text: String, replyTo: String?) {
        send(ChatMessage(id: UUID().uuidString, sender: SampleData.me, createdAt: Date(), content: .text(text)))
    }

    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        send(ChatMessage(
            id: UUID().uuidString,
            sender: SampleData.me,
            createdAt: Date(),
            attachments: attachments.map { outgoing in
                ChatAttachment(id: UUID().uuidString, kind: outgoing.kind, url: outgoing.fileURL, fileName: outgoing.fileName)
            }
        ))
    }

    /// Nothing fails here, so there is nothing to resend.
    func resendMessage(id: String) {}

    func removeFailedMessage(id: String) {}

    func stopObserving() {
        continuation?.finish()
        continuation = nil
    }
}

private extension AgentChannelRepository {
    func send(_ message: ChatMessage) {
        var message = message
        message.sendingStatus = .pending
        append(message)
        startRun(confirming: message.id)
    }

    func startRun(confirming sentMessageID: String? = nil) {
        run?.cancel()
        settleInterruptedRun()
        let runID = UUID().uuidString
        run = Task { [weak self] in
            try? await self?.play(runID: runID, confirming: sentMessageID)
        }
    }

    func play(runID: String, confirming sentMessageID: String?) async throws {
        if let sentMessageID {
            try await pause(for: Self.sendDelay)
            markSent(sentMessageID)
        }

        let statusID = "\(runID)-status"
        let startedAt = Date()
        append(step: .status(startedAt: startedAt, finishedAt: nil), id: statusID)

        try await think(id: "\(runID)-thinking-1")
        try await write(Script.opening, id: "\(runID)-opening")
        try await use(Script.tools, id: "\(runID)-tools")
        try await write(Script.finding, id: "\(runID)-finding")
        try await think(id: "\(runID)-thinking-2")
        try await write(Script.conclusion, id: "\(runID)-conclusion")

        update(id: statusID, to: .status(startedAt: startedAt, finishedAt: Date()))
    }

    func think(id: String) async throws {
        append(step: .thinking, id: id)
        try await pause(for: Self.thinkingDuration)
        remove(id: id)
    }

    func write(_ text: String, id: String) async throws {
        let words = text.split(separator: " ")
        append(step: .prose(String(words[0])), id: id)
        for count in 2...words.count {
            try await pause(for: Self.wordInterval)
            update(id: id, to: .prose(words.prefix(count).joined(separator: " ")))
        }
    }

    func use(_ tools: [ToolRun], id: String) async throws {
        append(step: .tools([tools[0]]), id: id)
        for count in 2...tools.count {
            try await pause(for: Self.toolInterval)
            update(id: id, to: .tools(Array(tools.prefix(count))))
        }
    }

    /// A sleep whose timer already fired returns normally even when the run was cancelled while
    /// its resume waited, so check again before the next write.
    func pause(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
        try Task.checkCancellation()
    }

    /// A run cut short by a new prompt would otherwise leave its thinking row, a status that keeps
    /// counting, and a prompt that never finishes sending.
    func settleInterruptedRun() {
        messages.removeAll { $0.customContent?.value(as: AgentStep.self) == .thinking }
        for index in messages.indices {
            if case let .status(startedAt, nil) = messages[index].customContent?.value(as: AgentStep.self) {
                set(.status(startedAt: startedAt, finishedAt: Date()), at: index)
            }
            if messages[index].sendingStatus == .pending {
                messages[index].sendingStatus = nil
            }
        }
        publish()
    }

    func markSent(_ id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        messages[index].sendingStatus = nil
        publish()
    }

    func append(step: AgentStep, id: String) {
        append(ChatMessage(
            id: id,
            sender: SampleData.assistant,
            createdAt: Date(),
            content: .text(step.plainText),
            customContent: step
        ))
    }

    func append(_ message: ChatMessage) {
        messages.append(message)
        publish()
    }

    func update(id: String, to step: AgentStep) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        set(step, at: index)
        publish()
    }

    func set(_ step: AgentStep, at index: Int) {
        messages[index].content = .text(step.plainText)
        messages[index].customContent = ChatMessage.CustomContent(step)
    }

    func remove(id: String) {
        messages.removeAll { $0.id == id }
        publish()
    }

    func publish() {
        continuation?.yield(messages)
    }
}

private enum Script {
    static let prompt = "Compare how the message list draws rows with the new reply stream, and tell me where they connect."

    static let opening = "I'll compare how the list receives messages and draws them with the new stream. First I'll find where the two can connect and what could break once they do."

    static let tools = [
        ToolRun(kind: .read, target: "ChannelContent.swift"),
        ToolRun(kind: .read, target: "MessageListDataSource.swift"),
        ToolRun(kind: .search, target: "reconfigureItems"),
        ToolRun(kind: .command, target: "git log --oneline -5")
    ]

    static let finding = "The list already updates a row in place when a message keeps its `id`, so streamed text needs no new API. The new stream can also replace a whole reply or shorten it, while the current typing animation assumes text only grows."

    static let conclusion = "Start with `snapshot` mode, which sends the full body every time and fits the list as it is. Tie the in-flight message to the confirmed one with `requestID`, so the same row carries on instead of showing twice."
}
