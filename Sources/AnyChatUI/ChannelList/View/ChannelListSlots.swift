import AnyChatCore
import SwiftUI

/// The custom views a host app has plugged into the channel list.
///
/// Stored on the view itself rather than in a global registry, so one screen's customization
/// never leaks into another.
struct ChannelListSlots {
    var row: ((ChatChannel) -> AnyView)?
    var coverImage: ((ChatChannel) -> AnyView)?
    var channelName: ((ChatChannel) -> AnyView)?
    var channelPreview: ((ChatChannel) -> AnyView)?
    var unreadCount: ((ChatChannel) -> AnyView)?
    var createChannelButton: (() -> AnyView)?
    var listHeader: (() -> AnyView)?
}

/// The callbacks a host app has registered.
struct ChannelListCallbacks {
    var channelSelected: ((ChatChannel) -> Void)?
    var createChannelTapped: (() -> Void)?
    var leftChannel: ((ChatChannel) -> Void)?
    var notificationLevelChanged: ((ChatChannel) -> Void)?
    var failed: ((any Error) -> Void)?
}
