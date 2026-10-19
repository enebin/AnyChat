import Foundation
import AnyChatDesignSystem

nonisolated extension Avatar.Content {
    init(_ cover: ChannelCover) {
        switch cover {
        case let .url(url):
            self = .image(url)
        case .broadcast:
            self = .broadcast
        case let .members(avatars):
            self = .members(avatars.map(\.profileImageURL))
        case .placeholder:
            self = .placeholder
        }
    }
}
