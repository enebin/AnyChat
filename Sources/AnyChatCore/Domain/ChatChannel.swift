import Foundation

/// A conversation, whatever kind the backend calls it.
///
/// Features a channel does not offer are `nil` or `false` rather than implied by a channel type,
/// so the UI decides what to show from these values alone.
///
/// - Since: 1.0.0
public struct ChatChannel: Sendable, Hashable, Identifiable {
    /// When the current user is notified about new messages.
    ///
    /// - Since: 1.0.0
    public enum NotificationLevel: Sendable, Hashable {
        case all
        case mentionsOnly
        case off
    }

    /// - Since: 1.0.0
    public var id: String

    /// The name a user gave the channel, or `nil` when it has none.
    ///
    /// - Since: 1.0.0
    public var name: String?

    /// The cover a user set, or `nil` when it has none.
    ///
    /// - Since: 1.0.0
    public var coverURL: URL?

    /// - Since: 1.0.0
    public var createdAt: Date

    /// The number of members, or `nil` when the backend does not count them.
    ///
    /// - Since: 1.0.0
    public var memberCount: Int?

    /// The members the backend knows about.
    ///
    /// - Since: 1.0.0
    public var members: [ChatSender]

    /// The latest sent message, or `nil` when there is none.
    ///
    /// Leave pending and failed messages out: the channel list draws this message with no
    /// sending status, so an unsent one would read as delivered.
    ///
    /// - Since: 1.0.0
    public var lastMessage: ChatMessage?

    /// The users typing right now.
    ///
    /// - Since: 1.0.0
    public var typingUsers: [ChatSender]

    /// The number of unread messages, or `nil` when the backend does not count them.
    ///
    /// - Since: 1.0.0
    public var unreadMessageCount: Int?

    /// The number of unread mentions, or `nil` when the backend does not count them.
    ///
    /// - Since: 1.0.0
    public var unreadMentionCount: Int?

    /// The current user's notification level, or `nil` when it cannot be changed.
    ///
    /// - Since: 1.0.0
    public var notificationLevel: NotificationLevel?

    /// Only operators can send messages.
    ///
    /// Describes the channel for display. Whether the current user can send is `canSendMessage`.
    ///
    /// - Since: 1.0.0
    public var isBroadcast: Bool

    /// Nobody can send messages.
    ///
    /// Describes the channel for display. Whether the current user can send is `canSendMessage`.
    ///
    /// - Since: 1.0.0
    public var isFrozen: Bool

    /// The current user can leave the channel.
    ///
    /// - Since: 1.0.0
    public var canLeave: Bool

    /// The current user can send messages now.
    ///
    /// Folds every backend rule into one value: a frozen channel, a broadcast channel for a
    /// non-operator, and a muted member are all `false`. Set it together with `isFrozen` and
    /// `isBroadcast`.
    ///
    /// - Since: 1.0.0
    public var canSendMessage: Bool

    /// The current user can reply to messages in this channel.
    ///
    /// Set it only when your repository sends replies: the screen offers no reply action while it
    /// is `false`, and never passes `replyTo` to the repository. Sending still depends on
    /// `canSendMessage`. Quotes of existing replies are drawn either way.
    ///
    /// - Since: 1.0.0
    public var canReply: Bool

    /// - Since: 1.0.0
    public init(
        id: String,
        name: String? = nil,
        coverURL: URL? = nil,
        createdAt: Date,
        memberCount: Int? = nil,
        members: [ChatSender] = [],
        lastMessage: ChatMessage? = nil,
        typingUsers: [ChatSender] = [],
        unreadMessageCount: Int? = nil,
        unreadMentionCount: Int? = nil,
        notificationLevel: NotificationLevel? = nil,
        isBroadcast: Bool = false,
        isFrozen: Bool = false,
        canLeave: Bool = false,
        canSendMessage: Bool = true,
        canReply: Bool = false
    ) {
        self.id = id
        self.name = name
        self.coverURL = coverURL
        self.createdAt = createdAt
        self.memberCount = memberCount
        self.members = members
        self.lastMessage = lastMessage
        self.typingUsers = typingUsers
        self.unreadMessageCount = unreadMessageCount
        self.unreadMentionCount = unreadMentionCount
        self.notificationLevel = notificationLevel
        self.isBroadcast = isBroadcast
        self.isFrozen = isFrozen
        self.canLeave = canLeave
        self.canSendMessage = canSendMessage
        self.canReply = canReply
    }
}
