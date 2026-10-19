import AnyChatCore
import SwiftUI

// MARK: - Custom views

public extension ChannelListView {
    /// Replaces an entire row. Swipe actions and pagination still work.
    ///
    /// The whole rectangle the row occupies opens the channel, including its blank space,
    /// so the row does not need its own `contentShape`.
    ///
    /// - Since: 1.0.0
    func channelRow(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        modified { $0.slots.row = { AnyView(content($0)) } }
    }

    /// Puts a view at the top of the list, above the first row, such as a strip of notes. It
    /// scrolls with the rows.
    ///
    /// The view spans the list's width with no insets and no separators; draw a divider in it if
    /// you want one. It is not a row: it does not open a channel and has no swipe actions. Buttons
    /// inside it take only their own taps, because the screen gives it the borderless button
    /// style; a style you set inside the view wins. Pagination is not affected.
    ///
    /// It shows while the channels load, when there are none, and when loading failed, since its
    /// content is your own data. The loading indicator, the empty message, and the error with
    /// Retry stay centered over the list; if the header is tall enough to reach the middle of the
    /// list, they draw over it. The closure runs again when you redraw the list with new data.
    ///
    /// ```swift
    /// ChannelListView()
    ///     .channelListHeader {
    ///         ScrollView(.horizontal, showsIndicators: false) {
    ///             HStack {
    ///                 ForEach(notes) { note in NoteBubble(note) }
    ///             }
    ///             .padding(.horizontal, 16)
    ///         }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func channelListHeader(@ViewBuilder _ content: @escaping () -> some View) -> Self {
        modified { $0.slots.listHeader = { AnyView(content()) } }
    }

    /// Replaces the channel avatar.
    ///
    /// - Since: 1.0.0
    func channelCoverImage(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        modified { $0.slots.coverImage = { AnyView(content($0)) } }
    }

    /// Replaces the channel title.
    ///
    /// - Since: 1.0.0
    func channelName(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        modified { $0.slots.channelName = { AnyView(content($0)) } }
    }

    /// Replaces the last message preview.
    ///
    /// - Since: 1.0.0
    func channelPreview(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        modified { $0.slots.channelPreview = { AnyView(content($0)) } }
    }

    /// Replaces the unread count badge.
    ///
    /// - Since: 1.0.0
    func channelUnreadCount(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        modified { $0.slots.unreadCount = { AnyView(content($0)) } }
    }

    /// Replaces the label of the navigation bar's create button.
    ///
    /// - Since: 1.0.0
    func createChannelButtonLabel(@ViewBuilder _ content: @escaping () -> some View) -> Self {
        modified { $0.slots.createChannelButton = { AnyView(content()) } }
    }

    /// Sets the navigation title. Defaults to `"Channels"`.
    ///
    /// - Since: 1.0.0
    func navigationTitleText(_ title: String) -> Self {
        modified { $0.title = title }
    }
}

// MARK: - Events

public extension ChannelListView {
    /// Called when a row is tapped. Use it to push your channel screen.
    ///
    /// - Since: 1.0.0
    func onChannelSelected(_ action: @escaping (ChatChannel) -> Void) -> Self {
        modified { $0.callbacks.channelSelected = action }
    }

    /// Called when the navigation bar's create button is tapped.
    ///
    /// - Since: 1.0.0
    func onCreateChannelTapped(_ action: @escaping () -> Void) -> Self {
        modified { $0.callbacks.createChannelTapped = action }
    }

    /// Called after the current user successfully leaves a channel.
    ///
    /// - Since: 1.0.0
    func onLeaveChannel(_ action: @escaping (ChatChannel) -> Void) -> Self {
        modified { $0.callbacks.leftChannel = action }
    }

    /// Called after the current user's notification level for a channel changes. The channel
    /// carries the new level.
    ///
    /// - Since: 1.0.0
    func onNotificationLevelChanged(_ action: @escaping (ChatChannel) -> Void) -> Self {
        modified { $0.callbacks.notificationLevelChanged = action }
    }

    /// Called when an action fails. Loading failures are shown in the list itself.
    ///
    /// - Since: 1.0.0
    func onError(_ action: @escaping (any Error) -> Void) -> Self {
        modified { $0.callbacks.failed = action }
    }
}

private extension ChannelListView {
    func modified(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}
