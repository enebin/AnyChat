import SwiftUI

public extension EnvironmentValues {
    /// The theme used by `ChannelListView` and its rows.
    ///
    /// - Since: 1.0.0
    @Entry var channelListTheme = ChannelListTheme.adaptive

    /// The theme used by `ChannelView` and its rows.
    ///
    /// - Since: 1.0.0
    @Entry var channelTheme = ChannelTheme.adaptive
}

public extension View {
    /// Applies a theme to the channel list in this part of the view tree.
    ///
    /// - Since: 1.0.0
    func channelListTheme(_ theme: ChannelListTheme) -> some View {
        environment(\.channelListTheme, theme)
    }

    /// Applies a theme to the channel screen in this part of the view tree.
    ///
    /// - Since: 1.0.0
    func channelTheme(_ theme: ChannelTheme) -> some View {
        environment(\.channelTheme, theme)
    }
}
