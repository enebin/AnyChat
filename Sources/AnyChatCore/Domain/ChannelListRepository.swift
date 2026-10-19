/// The backend boundary behind the channel list.
///
/// Main-actor isolated so an adapter can read its backend objects and turn them into values
/// within one isolation domain. Only `Sendable` values cross this boundary.
///
/// - Since: 1.0.0
@MainActor
public protocol ChannelListRepository: AnyObject {
    /// Starts (or restarts) observing and returns a stream of whole-list snapshots.
    ///
    /// Snapshots may be coalesced, so a burst of changes can surface as only its last snapshot.
    /// Send no snapshot until the first `loadMore()` after this call has its page; that page must
    /// include anything that changed meanwhile. The screen reads the stream only after that page,
    /// so an earlier snapshot would be shown after it and could replace it with older content.
    /// The stream finishes when `stopObserving()` is called or the consuming task is cancelled;
    /// either one releases whatever the backend holds for observing.
    ///
    /// - Since: 1.0.0
    func startObserving() -> AsyncStream<[ChatChannel]>

    /// Loads the next page and returns the whole list afterwards.
    ///
    /// - Since: 1.0.0
    func loadMore() async throws -> ChannelListPage

    /// Leaves the channel on behalf of the current user.
    ///
    /// - Throws: `ChannelListRepositoryError.channelNotFound` when no listed channel has this id.
    /// - Since: 1.0.0
    func leave(channelID: String) async throws

    /// Changes the current user's notification level and then publishes a new snapshot.
    ///
    /// - Throws: `ChannelListRepositoryError.channelNotFound` when no listed channel has this id.
    /// - Since: 1.0.0
    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws

    /// Stops observing and finishes the snapshot stream. Does nothing when not observing.
    ///
    /// - Since: 1.0.0
    func stopObserving()
}

/// The result of loading a page.
///
/// `channels` is the whole list so far, not just the channels this page added.
///
/// - Since: 1.0.0
public struct ChannelListPage: Sendable, Hashable {
    /// - Since: 1.0.0
    public var channels: [ChatChannel]

    /// - Since: 1.0.0
    public var hasNext: Bool

    /// - Since: 1.0.0
    public init(channels: [ChatChannel], hasNext: Bool) {
        self.channels = channels
        self.hasNext = hasNext
    }
}

/// - Since: 1.0.0
public enum ChannelListRepositoryError: Error, Equatable {
    /// `loadMore()` was called before `startObserving()`.
    case notObserving
    /// The backend is not ready, usually because it is not initialized or connected.
    case unavailable
    /// No listed channel has the requested id.
    case channelNotFound
}
