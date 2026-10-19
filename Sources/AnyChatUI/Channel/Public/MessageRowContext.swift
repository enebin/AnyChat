/// What a message slot needs to know about where its message sits on screen.
///
/// The message itself carries the content; this carries what the screen derived from the
/// messages around it.
///
/// - Since: 1.0.0
nonisolated public struct MessageRowContext: Sendable, Hashable {
    /// Where a message sits in a run of messages one person sent within the same minute. A reply
    /// (a message with `replyTo`) always starts a new run, so its quote never sits between two
    /// bubbles of one run.
    ///
    /// For someone else's messages the default row puts the name on `.single` and `.first`, and
    /// the picture and time on `.single` and `.last`. For the current user's messages it shows no
    /// name or picture, and puts the time and receipt on `.single` and `.last`.
    ///
    /// - Since: 1.0.0
    public enum GroupPosition: Sendable, Hashable {
        /// Alone: no neighbor joins it.
        ///
        /// - Since: 1.0.0
        case single
        /// The oldest message of a run, at its top.
        ///
        /// - Since: 1.0.0
        case first
        /// Between the first and the last.
        ///
        /// - Since: 1.0.0
        case middle
        /// The newest message of a run, at its bottom.
        ///
        /// - Since: 1.0.0
        case last
    }

    /// Whether the current user sent the message.
    ///
    /// A pending or failed message is always the current user's. A sent message is the current
    /// user's only when its sender's id equals the screen's current user id, so without a current
    /// user id every sent message is someone else's.
    ///
    /// - Since: 1.0.0
    public var isMine: Bool

    /// Where the message sits in its run.
    ///
    /// - Since: 1.0.0
    public var groupPosition: GroupPosition

    /// Creates a context, for example to preview a custom row.
    ///
    /// - Since: 1.0.0
    public init(isMine: Bool, groupPosition: GroupPosition) {
        self.isMine = isMine
        self.groupPosition = groupPosition
    }
}
