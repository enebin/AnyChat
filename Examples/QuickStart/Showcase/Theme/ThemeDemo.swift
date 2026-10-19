import SwiftUI
import AnyChatUI

/// Restyles the channel list and the channel screen with a theme preset through
/// `.channelListTheme(_:)` and `.channelTheme(_:)`.
struct ThemeDemo: View {
    @State private var backend = SampleChatBackend()
    @State private var preset = ThemePreset.light
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        ChannelListView()
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Themes")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Theme", selection: $preset) {
                        ForEach(ThemePreset.allCases, id: \.self) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            // A pushed view takes its environment from the stack, which sits above this demo.
            .navigationDestination(item: $selectedChannel) { channel in
                ChannelView(channel: channel)
                    .channelTheme(preset.channelTheme)
                    .chatBackend(backend)
            }
            .channelListTheme(preset.channelListTheme)
            // The themes do not style the navigation bar, so match it to the preset.
            .preferredColorScheme(preset.colorScheme)
            .chatBackend(backend)
    }
}

private enum ThemePreset: CaseIterable {
    case light
    case dark
    case brand

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .brand: "Brand"
        }
    }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    var channelListTheme: ChannelListTheme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .brand: .brand
        }
    }

    var channelTheme: ChannelTheme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .brand: .brand
        }
    }
}

private enum BrandColor {
    static let primary = Color(red: 0.05, green: 0.55, blue: 0.45)
    static let tint = Color(red: 0.88, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.17)
    static let accent = Color(red: 0.95, green: 0.55, blue: 0.15)
}

private extension ChannelListTheme {
    static let brand = ChannelListTheme(
        background: BrandColor.tint,
        titleText: BrandColor.ink,
        frozenMark: BrandColor.accent,
        unreadBadgeBackground: BrandColor.accent,
        unreadMentionText: BrandColor.accent,
        separator: BrandColor.primary.opacity(0.25),
        coverPlaceholderBackground: BrandColor.primary,
        barButtonTint: BrandColor.primary,
        titleFont: .system(.headline, design: .rounded),
        messageFont: .system(.subheadline, design: .rounded)
    )
}

private extension ChannelTheme {
    static let brand = ChannelTheme(
        background: BrandColor.tint,
        headerTitleText: BrandColor.ink,
        incomingBubbleBackground: .white,
        outgoingBubbleBackground: BrandColor.primary,
        incomingMessageText: BrandColor.ink,
        avatarPlaceholderBackground: BrandColor.primary,
        accent: BrandColor.primary,
        composerBackground: BrandColor.tint,
        composerFieldBackground: .white,
        composerButtonTint: BrandColor.primary,
        frozenBannerBackground: BrandColor.accent,
        headerTitleFont: .system(.headline, design: .rounded),
        messageFont: .system(.body, design: .rounded),
        composerFont: .system(.body, design: .rounded),
        frozenBannerFont: .system(.footnote, design: .rounded).weight(.semibold)
    )
}
