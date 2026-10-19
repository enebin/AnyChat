import SwiftUI
import UIKit

/// Semantic system colors resolved for each built-in appearance.
nonisolated package enum ChatPalette {
    package static let light = Appearance(style: .light)
    package static let dark = Appearance(style: .dark)
    package static let onAccent = Color.white
    package static let groupAvatarBackground = Color(red: 116 / 255, green: 116 / 255, blue: 128 / 255, opacity: 0.08)
    /// Measured from the iOS 26 system context menu; the same tint in light and dark.
    package static let overlayDim = Color(red: 0, green: 0, blue: 25 / 255, opacity: 0.16)

    package struct Appearance: Sendable {
        package let background: Color
        package let secondaryBackground: Color
        package let bubbleBackground: Color
        package let label: Color
        package let secondaryLabel: Color
        package let tertiaryLabel: Color
        package let placeholder: Color
        package let separator: Color
        package let avatarBackground: Color
        package let accent: Color
        package let cursor: Color
        package let quoteText: Color
        package let quoteBorder: Color
        package let closeFill: Color
        package let destructive: Color
        package let neutral: Color

        fileprivate init(style: UIUserInterfaceStyle) {
            background = color(.systemBackground, style: style)
            secondaryBackground = color(.secondarySystemBackground, style: style)
            let isDark = style == .dark
            bubbleBackground = kit(isDark ? UIColor(red: 38 / 255, green: 38 / 255, blue: 41 / 255, alpha: 1) : UIColor(red: 233 / 255, green: 233 / 255, blue: 234 / 255, alpha: 1), system: .systemGray5, style: style)
            label = color(.label, style: style)
            secondaryLabel = color(.secondaryLabel, style: style)
            tertiaryLabel = color(.tertiaryLabel, style: style)
            placeholder = kit(isDark ? UIColor(red: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 0.4) : UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.4), system: .placeholderText, style: style)
            separator = isDark ? color(.separator, style: style) : kit(UIColor(white: 0, alpha: 0.12), system: .separator, style: style)
            avatarBackground = color(.systemGray3, style: style)
            accent = kit(UIColor(red: 0, green: 136 / 255, blue: 1, alpha: 1), system: .systemBlue, style: style)
            quoteText = kit(isDark ? UIColor(red: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 0.78) : UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.78), system: .secondaryLabel, style: style)
            quoteBorder = kit(isDark ? UIColor(red: 84 / 255, green: 84 / 255, blue: 88 / 255, alpha: 0.65) : UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.29), system: .separator, style: style)
            closeFill = kit(UIColor(red: 120 / 255, green: 120 / 255, blue: 128 / 255, alpha: isDark ? 0.36 : 0.16), system: .secondarySystemFill, style: style)
            cursor = kit(UIColor(red: 0, green: 145 / 255, blue: 1, alpha: 1), system: .systemBlue, style: style)
            destructive = color(.systemRed, style: style)
            neutral = color(.systemGray, style: style)
        }
    }

    package static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            let selected = traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            return selected.resolvedColor(with: traits)
        })
    }

    /// The Messages kit's value, except under Increase Contrast, where the system colour it stands
    /// in for gives the stronger variant the kit does not define.
    private static func kit(_ value: UIColor, system: UIColor, style: UIUserInterfaceStyle) -> Color {
        Color(UIColor { traits in
            guard traits.accessibilityContrast == .high else {
                return value
            }
            return system.resolvedColor(with: traits.modifyingTraits { $0.userInterfaceStyle = style })
        })
    }

    private static func color(_ color: UIColor, style: UIUserInterfaceStyle) -> Color {
        Color(UIColor { traits in
            color.resolvedColor(with: traits.modifyingTraits { $0.userInterfaceStyle = style })
        })
    }
}
