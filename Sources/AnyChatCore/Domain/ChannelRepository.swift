/// The backend boundary behind one channel's message list.
///
/// Main-actor isolated so an adapter can read its backend objects and turn them into values
/// within one isolation domain. Only `Sendable` values cross this boundary.
///
/// Messages are ordered oldest first, except that this device's pending and failed messages
/// follow every sent message, in the order they were sent. Every snapshot, from the stream or from
/// a page, holds every message read so far, including those pending and failed messages, in every
/// observation of the channel. A message that changes in place comes back with the same `id`.
///
/// - Since: 1.0.0
@MainActor
public protocol ChannelRepository: AnyObject {
    /// Starts (or restarts) observing and returns a stream of whole-list snapshots.
    ///
    /// Each call opens its own observation and resets paging, so the next `loadPrevious()`
    /// returns the latest page again. Snapshots may be coalesced, so a burst of changes can
    /// surface as only its last snapshot. Send no snapshot until the first `loadPrevious()` after
    /// this call has its page; that page must include anything that arrived meanwhile. The screen
    /// reads the stream only after that page, so an earlier snapshot would be shown after it and
    /// could replace it with older content. Open backend resources here, not when the repository
    /// is made: a screen may make and discard repositories it never observes.
    ///
    /// Finish the stream when the channel can no longer be shown, for example because it was
    /// deleted or the current user was removed. Do not send an empty snapshot instead: an
    /// empty list means the channel has no messages. When the stream ends, release only what
    /// this call opened; a newer observation may already be running.
    ///
    /// - Since: 1.0.0
    func startObserving() -> AsyncStream<[ChatMessage]>

    /// Loads one more page into the past and returns every message read so far.
    ///
    /// The first call after `startObserving()` returns the latest page. After a page loads,
    /// also send the same messages as a new snapshot on the stream.
    ///
    /// - Throws: `ChannelRepositoryError.channelNotFound` when the channel can no longer be shown.
    /// - Since: 1.0.0
    func loadPrevious() async throws -> MessagePage

    /// Sends a text message from the current user, as a reply when `replyTo` is set.
    ///
    /// Returns at once. Put a pending message in the next snapshot, after every sent message, and
    /// later replace it with the sent message under the same `id`, or mark it failed. Report a
    /// failure, including one before the request leaves the device, as a failed message rather
    /// than an error. The screen calls this only while observing, with text that is trimmed and
    /// not empty. Keep sending after `stopObserving()` or after the stream ends.
    ///
    /// `replyTo` is the `id` of the message being answered, or `nil` for an ordinary message. The
    /// screen passes one only while the channel's `canReply` is `true`, for a sent, non-system
    /// message it holds. Give the pending message a `ChatMessage.replyTo` built from the original
    /// from its first snapshot, and keep it through sending, failing, and resending. When you do
    /// not have the original, use `ChatMessage.ReplyReference.unavailable(messageID:)` until the
    /// backend's reply link is known. A backend that rejects the reply turns it into a failed
    /// message.
    ///
    /// - Since: 1.0.0
    func sendMessage(text: String, replyTo: String?)

    /// Sends one message holding every attachment, in order, from the current user, as a reply
    /// when `replyTo` is set.
    ///
    /// Returns at once and reports the outcome through snapshots, like
    /// `sendMessage(text:replyTo:)`, which also describes `replyTo`. The
    /// pending message's `ChatAttachment.url` may point at the local files until the upload ends.
    /// The files belong to the adapter after the call, not to this repository instance: keep each
    /// file as long as its message may be resent, even after `stopObserving()` or after this
    /// repository is released. The screen reads them again only through the `ChatAttachment.url`
    /// values you put in snapshots, and never deletes them. The screen never passes an empty list.
    ///
    /// - Since: 1.0.0
    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?)

    /// Sends a failed message again, keeping its `id`, and as the same reply if it was one.
    ///
    /// Returns at once; the outcome arrives in snapshots. Does nothing unless the message is a
    /// failed message sent from this device, so a repeated call never sends twice.
    ///
    /// - Since: 1.0.0
    func resendMessage(id: String)

    /// Removes a failed message sent from this device from later snapshots.
    ///
    /// Returns at once. Does nothing for a pending, sent, or unknown message.
    ///
    /// - Since: 1.0.0
    func removeFailedMessage(id: String)

    /// Stops observing and finishes the snapshot stream. Does nothing when not observing.
    ///
    /// - Since: 1.0.0
    func stopObserving()
}

/// The result of loading a page of messages.
///
/// `messages` is every message read so far, not just the messages this page added: sent messages
/// oldest first, then this device's pending and failed messages in the order they were sent.
///
/// - Since: 1.0.0
public struct MessagePage: Sendable, Hashable {
    /// - Since: 1.0.0
    public var messages: [ChatMessage]

    /// Whether older messages remain to be loaded.
    ///
    /// - Since: 1.0.0
    public var hasPrevious: Bool

    /// - Since: 1.0.0
    public init(messages: [ChatMessage], hasPrevious: Bool) {
        self.messages = messages
        self.hasPrevious = hasPrevious
    }
}

/// - Since: 1.0.0
public enum ChannelRepositoryError: Error, Equatable {
    /// `loadPrevious()` was called before `startObserving()`.
    case notObserving
    /// The backend is not ready, usually because it is not initialized or connected.
    case unavailable
    /// The channel was deleted or the current user can no longer see it.
    case channelNotFound
}
