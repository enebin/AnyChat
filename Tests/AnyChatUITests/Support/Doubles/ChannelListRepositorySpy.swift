import AnyChatCore

/// Stands in for a backend so the screen can be driven without a connection.
@MainActor
final class ChannelListRepositorySpy: ChannelListRepository {
    private(set) var startObservingCount = 0
    private(set) var stopObservingCount = 0
    private(set) var loadMoreCount = 0
    private(set) var leftChannelIDs: [String] = []
    private(set) var notificationLevelChanges: [(channelID: String, level: ChatChannel.NotificationLevel)] = []

    /// Results handed to successive `loadMore()` calls. The last one repeats once exhausted.
    var loadMoreResults: [Result<ChannelListPage, any Error>] = [.success(.init(channels: [], hasNext: false))]
    var leaveResult: Result<Void, any Error> = .success(())
    var notificationLevelResult: Result<Void, any Error> = .success(())

    /// When `true`, `loadMore()` suspends until `resumeLoadMore(with:)` is called.
    var holdsLoadMore = false

    /// Held calls, oldest first.
    private var heldLoadMores: [CheckedContinuation<ChannelListPage, any Error>] = []
    private var continuation: AsyncStream<[ChatChannel]>.Continuation?

    func startObserving() -> AsyncStream<[ChatChannel]> {
        startObservingCount += 1
        continuation?.finish()

        let (stream, continuation) = AsyncStream<[ChatChannel]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation

        // Mirrors a real adapter: ending the stream releases the backend's resources.
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.stopObserving()
            }
        }

        return stream
    }

    func loadMore() async throws -> ChannelListPage {
        loadMoreCount += 1

        if holdsLoadMore {
            return try await withCheckedThrowingContinuation { heldLoadMores.append($0) }
        }

        return try nextResult().get()
    }

    func leave(channelID: String) async throws {
        leftChannelIDs.append(channelID)
        try leaveResult.get()
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {
        notificationLevelChanges.append((channelID: channelID, level: level))
        try notificationLevelResult.get()
    }

    func stopObserving() {
        stopObservingCount += 1
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Test control

    /// Completes the oldest `loadMore()` that is still held back.
    func resumeLoadMore(with result: Result<ChannelListPage, any Error>) {
        guard !heldLoadMores.isEmpty else {
            return
        }
        heldLoadMores.removeFirst().resume(with: result)
    }

    /// Simulates a live change.
    func emit(_ channels: [ChatChannel]) {
        continuation?.yield(channels)
    }

    private func nextResult() -> Result<ChannelListPage, any Error> {
        loadMoreResults.count > 1 ? loadMoreResults.removeFirst() : (loadMoreResults.first ?? .success(.init(channels: [], hasNext: false)))
    }
}
