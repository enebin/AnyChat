import Foundation

/// A message, carrying what a channel list preview and a message list need.
///
/// A message that changes in place, such as an edit or streamed text, comes back with the same
/// `id`.
///
/// - Since: 1.0.0
public struct ChatMessage: Sendable, Hashable, Identifiable {
    /// What the message holds.
    ///
    /// - Since: 1.0.0
    public enum Content: Sendable, Hashable {
        /// Text written by a user.
        case text(String)
        /// Text written by the backend, such as "Alice joined".
        case system(String)
        /// A single file.
        case file(FileKind)
        /// Several files sent together.
        case files
        /// Anything this package cannot show.
        case unsupported
    }

    /// What kind of file a file message carries. The backend decides, not the UI.
    ///
    /// - Since: 1.0.0
    public enum FileKind: Sendable, Hashable {
        case image
        case gif
        case video
        case audio
        /// A recorded voice message.
        case voice
        case other
    }

    /// How far the message has reached the other members.
    ///
    /// - Since: 1.0.0
    public enum Receipt: Sendable, Hashable {
        case sent
        case delivered
        case read
    }

    /// How far a message sent from this device has got.
    ///
    /// - Since: 1.0.0
    public enum SendingStatus: Sendable, Hashable {
        /// The message is on its way to the backend.
        case pending
        /// The message did not reach the backend. It can be resent or removed.
        case failed
    }

    /// - Since: 1.0.0
    public var id: String

    /// The sender, or `nil` for messages the backend wrote itself.
    ///
    /// - Since: 1.0.0
    public var sender: ChatSender?

    /// - Since: 1.0.0
    public var createdAt: Date

    /// - Since: 1.0.0
    public var content: Content

    /// Files accompanying an ordinary message's content, in display order.
    ///
    /// System notice rendering does not use attachments.
    ///
    /// - Since: 1.0.0
    public var attachments: [ChatAttachment]

    /// An app-defined value rendered by a matching channel slot. `content` supplies the fallback.
    ///
    /// - Since: 1.0.0
    public var customContent: CustomContent?

    /// App-defined state, such as "reported", kept apart from `customContent`, which picks the
    /// renderer.
    ///
    /// The adapter sets it from the backend. Set it after creating the message. No default view
    /// reads it.
    ///
    /// - Since: 1.0.0
    public var attributes: Attributes

    /// The delivery state, or `nil` when the backend does not track receipts for this message.
    ///
    /// Applies only once `sendingStatus` is `nil`.
    ///
    /// - Since: 1.0.0
    public var receipt: Receipt?

    /// The sending state of a message sent from this device, or `nil` once it reached the
    /// backend and for every message sent elsewhere.
    ///
    /// The adapter owns this value and carries it in snapshots. Set it after creating the message.
    /// A pending message that is sent keeps its `id` and only loses this status.
    ///
    /// - Since: 1.0.0
    public var sendingStatus: SendingStatus?

    /// The message this one answers, or `nil` for an ordinary message.
    ///
    /// Fill it from the backend's reply link for every message that has one, including other
    /// users' messages and messages on earlier pages. Set it after creating the message.
    ///
    /// - Since: 1.0.0
    public var replyTo: ReplyReference?

    /// - Since: 1.0.0
    public init(
        id: String,
        sender: ChatSender? = nil,
        createdAt: Date,
        content: Content,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.sender = sender
        self.createdAt = createdAt
        self.content = content
        self.attachments = []
        self.customContent = nil
        self.attributes = Attributes()
        self.receipt = receipt
        self.sendingStatus = nil
        self.replyTo = nil
    }

    /// Creates a message carrying an app-defined value without adding a new `Content` case.
    ///
    /// `content` supplies the channel list preview and the row shown without a matching renderer.
    /// Keep the same `id` when updating the custom value in place.
    ///
    /// - Since: 1.0.0
    public init<Value: Hashable & Sendable>(
        id: String,
        sender: ChatSender? = nil,
        createdAt: Date,
        content: Content = .unsupported,
        customContent: Value,
        receipt: Receipt? = nil
    ) {
        self.init(id: id, sender: sender, createdAt: createdAt, content: content, receipt: receipt)
        self.customContent = CustomContent(customContent)
    }

    /// Creates an ordinary message with a text body and an ordered attachment list.
    ///
    /// An empty body supports attachment-only messages; an empty list supports text-only messages.
    ///
    /// - Since: 1.0.0
    public init(
        id: String,
        sender: ChatSender? = nil,
        createdAt: Date,
        text: String = "",
        attachments: [ChatAttachment],
        receipt: Receipt? = nil
    ) {
        self.init(id: id, sender: sender, createdAt: createdAt, content: .text(text), receipt: receipt)
        self.attachments = attachments
    }

    /// Creates an ordinary message combining text, attachments, and an app-defined value.
    ///
    /// - Since: 1.0.0
    public init<Value: Hashable & Sendable>(
        id: String,
        sender: ChatSender? = nil,
        createdAt: Date,
        text: String = "",
        attachments: [ChatAttachment],
        customContent: Value,
        receipt: Receipt? = nil
    ) {
        self.init(id: id, sender: sender, createdAt: createdAt, text: text, attachments: attachments, receipt: receipt)
        self.customContent = CustomContent(customContent)
    }
}
