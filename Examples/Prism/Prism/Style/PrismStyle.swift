import SwiftUI
import AnyChatUI

enum PrismStyle {
    static let accent = Color(.systemBlue)
    static let outgoingGradient = LinearGradient(
        colors: [Color(.systemBlue), Color(.systemTeal)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let storyRing = AngularGradient(
        colors: [.yellow, .orange, .pink, .blue, .orange, .yellow],
        center: .center
    )
    static let incomingBubble = Color(.secondarySystemBackground)
    static let online = Color(.systemGreen)

    static var channelTheme: ChannelTheme {
        var theme = ChannelTheme.adaptive
        theme.background = Color(.systemBackground)
        theme.incomingMessageText = .primary
        theme.outgoingMessageText = .white
        theme.receiptRead = accent
        theme.accent = accent
        theme.composerBackground = Color(.systemBackground)
        theme.composerButtonTint = accent
        theme.messageFont = .system(size: 16)
        theme.headerTitleFont = .system(size: 16, weight: .semibold)
        return theme
    }

    static var channelListTheme: ChannelListTheme {
        var theme = ChannelListTheme.adaptive
        theme.background = Color(.systemBackground)
        theme.separator = .clear
        theme.barButtonTint = .primary
        return theme
    }
}

/// A person's picture: their initials on a color picked from their id, with a ring while they have a
/// story and a dot while they are online.
struct PrismAvatar: View {
    let person: ChatSender
    var size: CGFloat = 56
    var showsStory = true
    var showsActivity = true

    private static let palettes: [[Color]] = [
        [.pink, .orange], [.blue, .cyan], [.teal, .blue], [.mint, .green], [.blue, .cyan], [.orange, .yellow], [.red, .pink]
    ]

    private var profile: PrismProfile? { PrismSampleData.profile(person) }

    var body: some View {
        let ring = showsStory && profile?.hasStory == true
        ZStack {
            Circle()
                .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(ring ? size * 0.07 : 0)
            if ring {
                Circle().strokeBorder(PrismStyle.storyRing, lineWidth: size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if showsActivity, profile?.isActive == true, person.id != PrismBackend.me.id {
                Circle()
                    .fill(PrismStyle.online)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: size * 0.05))
            }
        }
        .accessibilityHidden(true)
    }

    private var initials: String {
        (person.name ?? person.id)
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    private var palette: [Color] {
        let index = person.id.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }
        return Self.palettes[abs(index) % Self.palettes.count]
    }
}

/// Two overlapping pictures for a group.
struct PrismGroupAvatar: View {
    let members: [ChatSender]
    var size: CGFloat = 56

    var body: some View {
        let others = members.filter { $0.id != PrismBackend.me.id }.prefix(2)
        ZStack(alignment: .topLeading) {
            ForEach(Array(others.enumerated()), id: \.element.id) { index, person in
                PrismAvatar(person: person, size: size * 0.7, showsStory: false, showsActivity: false)
                    .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                    .offset(x: index == 0 ? 0 : size * 0.3, y: index == 0 ? 0 : size * 0.3)
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

extension Date {
    /// "now", "5m", "3h", "2d", "4w".
    var shortAgo: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return "\(Int(seconds / 604_800))w"
        }
    }
}

extension ChatChannel {
    var friend: ChatSender? {
        members.count == 2 ? members.first { $0.id != PrismBackend.me.id } : nil
    }
}
