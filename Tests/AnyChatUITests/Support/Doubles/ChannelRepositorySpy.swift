import AnyChatCore

/// Stands in for a backend so the channel screen can be driven without a connection.
@MainActor
final class ChannelRepositorySpy: ChannelRepository {
    private(set) var startObservingCount = 0
    private(set) var loadPreviousCount = 0
    /// How many streams have ended, whether by cancellation or by `finishStream()`.
    private(set) var terminatedStreamCount = 0
    private(set) var sentTexts: [String] = []
    private(set) var sentAttachments: [[ChatOutgoingAttachment]] = []
    /// The `replyTo` of every send, text and attachments alike, in call order.
    private(set) var sentReplyTos: [String?] = []
    private(set) var resentMessageIDs: [String] = []
    private(set) var removedMessageIDs: [String] = []

    /// Results handed to successive `loadPrevious()` calls. The last one repeats once exhausted.
    var loadPreviousResults: [Result<MessagePage, any Error>] = [.success(.init(messages: [], hasPrevious: false))]

    /// When `true`, `loadPrevious()` suspends until `resumeLoadPrevious(with:)` is called.
    var holdsLoadPrevious = false

    /// Held calls, oldest first.
    private var heldLoadPrevious: [CheckedContinuation<MessagePage, any Error>] = []
    private var continuation: AsyncStream<[ChatMessage]>.Continuation?

    func startObserving() -> AsyncStream<[ChatMessage]> {
        startObservingCount += 1

        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation

        // Releases only what this call opened: the next observation may already be running
        // when this runs.
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.terminatedStreamCount += 1
            }
        }

        return stream
    }

    func loadPrevious() async throws -> MessagePage {
        loadPreviousCount += 1

        if holdsLoadPrevious {
            return try await withCheckedThrowingContinuation { heldLoadPrevious.append($0) }
        }

        return try nextResult().get()
    }

    func sendMessage(text: String, replyTo: String?) {
        sentTexts.append(text)
        sentReplyTos.append(replyTo)
    }

    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        sentAttachments.append(attachments)
        sentReplyTos.append(replyTo)
    }

    func resendMessage(id: String) {
        resentMessageIDs.append(id)
    }

    func removeFailedMessage(id: String) {
        removedMessageIDs.append(id)
    }

    func stopObserving() {
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Test control

    /// Completes the oldest `loadPrevious()` that is still held back.
    func resumeLoadPrevious(with result: Result<MessagePage, any Error>) {
        guard !heldLoadPrevious.isEmpty else {
            return
        }
        heldLoadPrevious.removeFirst().resume(with: result)
    }

    /// Simulates a live change.
    func emit(_ messages: [ChatMessage]) {
        continuation?.yield(messages)
    }

    /// Simulates losing the channel: the adapter ends the stream on its own.
    func finishStream() {
        continuation?.finish()
    }

    private func nextResult() -> Result<MessagePage, any Error> {
        loadPreviousResults.count > 1
            ? loadPreviousResults.removeFirst()
            : (loadPreviousResults.first ?? .success(.init(messages: [], hasPrevious: false)))
    }
}
