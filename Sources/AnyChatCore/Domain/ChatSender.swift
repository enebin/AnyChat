import Foundation

/// A participant that can send messages, such as a person, bot, or agent.
///
/// - Since: 1.0.0
public struct ChatSender: Sendable, Hashable, Identifiable {
    /// - Since: 1.0.0
    public var id: String

    /// The display name, or `nil` when the sender has no display name.
    ///
    /// - Since: 1.0.0
    public var name: String?

    /// The sender's picture, or `nil` when no picture is available.
    ///
    /// - Since: 1.0.0
    public var profileImageURL: URL?

    /// - Since: 1.0.0
    public init(id: String, name: String? = nil, profileImageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.profileImageURL = profileImageURL
    }
}
