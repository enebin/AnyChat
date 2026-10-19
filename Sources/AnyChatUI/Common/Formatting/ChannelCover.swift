import Foundation
import AnyChatCore

/// How to draw a channel's avatar. Channel list rows and the channel header both use it.
nonisolated enum ChannelCover: Hashable {
    case url(URL)
    case broadcast
    case members([MemberAvatar])
    case placeholder

    struct MemberAvatar: Hashable {
        let userID: String
        let profileImageURL: URL?
    }

    /// Avatars beyond the fourth are dropped; the group avatar holds up to four member circles.
    static let maxAvatarCount = 4

    static func resolve(for channel: ChatChannel, currentUserID: String?) -> ChannelCover {
        if let coverURL = channel.coverURL {
            return .url(coverURL)
        }

        if channel.isBroadcast {
            return .broadcast
        }

        let others = channel.members.filter { $0.id != currentUserID }
        guard !others.isEmpty else {
            return .placeholder
        }

        return .members(
            others.prefix(maxAvatarCount).map { member in
                MemberAvatar(userID: member.id, profileImageURL: member.profileImageURL)
            }
        )
    }
}
