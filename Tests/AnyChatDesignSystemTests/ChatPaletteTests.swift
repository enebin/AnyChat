import SwiftUI
import XCTest
@testable import AnyChatDesignSystem

@MainActor
final class ChatPaletteTests: XCTestCase {
    func testFixedAppearancesUseSystemColorsEvenUnderOppositeTraits() {
        // Given
        let pairs: [(ChatPalette.Appearance, UIUserInterfaceStyle, UIUserInterfaceStyle)] = [
            (ChatPalette.light, .light, .dark), (ChatPalette.dark, .dark, .light)
        ]

        for (palette, expectedStyle, surroundingStyle) in pairs {
            let expectedTraits = UITraitCollection(userInterfaceStyle: expectedStyle)
            let surroundingTraits = UITraitCollection(userInterfaceStyle: surroundingStyle)
            let colors: [(Color, UIColor)] = [
                (palette.background, .systemBackground), (palette.label, .label),
                (palette.destructive, .systemRed)
            ]

            // When / Then
            for (actual, expected) in colors {
                XCTAssertEqual(
                    UIColor(actual).resolvedColor(with: surroundingTraits),
                    expected.resolvedColor(with: expectedTraits)
                )
            }
        }
    }

    func testKitColorsUseTheDesignSourceValuesInBothAppearances() {
        // Given
        let normal = UITraitCollection(accessibilityContrast: .normal)
        let expected: [(Color, UIColor)] = [
            (ChatPalette.light.bubbleBackground, Kit.lightIncomingBubble), (ChatPalette.dark.bubbleBackground, Kit.darkIncomingBubble),
            (ChatPalette.light.accent, Kit.blue), (ChatPalette.dark.accent, Kit.blue),
            (ChatPalette.light.cursor, Kit.cursor), (ChatPalette.dark.cursor, Kit.cursor),
            (ChatPalette.light.placeholder, Kit.lightPlaceholder), (ChatPalette.dark.placeholder, Kit.darkPlaceholder),
            (ChatPalette.light.separator, Kit.lightSeparator),
            (ChatPalette.light.quoteText, Kit.lightQuoteText), (ChatPalette.dark.quoteText, Kit.darkQuoteText),
            (ChatPalette.light.quoteBorder, Kit.lightQuoteBorder), (ChatPalette.dark.quoteBorder, Kit.darkQuoteBorder)
        ]

        for (actual, value) in expected {
            // When / Then
            XCTAssertEqual(UIColor(actual).resolvedColor(with: normal), value)
        }
    }

    func testKitColorsFallBackToSystemColorsUnderIncreasedContrast() {
        // Given
        let pairs: [(Color, UIColor, UIUserInterfaceStyle)] = [
            (ChatPalette.light.accent, .systemBlue, .light), (ChatPalette.dark.accent, .systemBlue, .dark),
            (ChatPalette.light.bubbleBackground, .systemGray5, .light), (ChatPalette.dark.bubbleBackground, .systemGray5, .dark)
        ]

        for (actual, system, style) in pairs {
            let traits = UITraitCollection { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = .high
            }

            // When / Then
            XCTAssertEqual(UIColor(actual).resolvedColor(with: traits), system.resolvedColor(with: traits))
        }
    }

    func testAdaptiveColorsPreserveAppearanceAndIncreasedContrast() {
        // Given
        let adaptive = UIColor(ChatPalette.adaptive(light: ChatPalette.light.accent, dark: ChatPalette.dark.accent))

        for style: UIUserInterfaceStyle in [.light, .dark] {
            for contrast: UIAccessibilityContrast in [.normal, .high] {
                let traits = UITraitCollection { traits in
                    traits.userInterfaceStyle = style
                    traits.accessibilityContrast = contrast
                }

                // When
                let actual = adaptive.resolvedColor(with: traits)

                // Then
                XCTAssertEqual(actual, contrast == .high ? UIColor.systemBlue.resolvedColor(with: traits) : Kit.blue)
            }
        }
    }
}

/// The Messages kit's values from docs/design/messages/README.md.
enum Kit {
    static let blue = UIColor(red: 0, green: 136 / 255, blue: 1, alpha: 1)
    static let cursor = UIColor(red: 0, green: 145 / 255, blue: 1, alpha: 1)
    static let lightIncomingBubble = UIColor(red: 233 / 255, green: 233 / 255, blue: 234 / 255, alpha: 1)
    static let darkIncomingBubble = UIColor(red: 38 / 255, green: 38 / 255, blue: 41 / 255, alpha: 1)
    static let lightPlaceholder = UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.4)
    static let darkPlaceholder = UIColor(red: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 0.4)
    static let lightSeparator = UIColor(white: 0, alpha: 0.12)
    static let lightQuoteText = UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.78)
    static let darkQuoteText = UIColor(red: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 0.78)
    static let lightQuoteBorder = UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.29)
    static let darkQuoteBorder = UIColor(red: 84 / 255, green: 84 / 255, blue: 88 / 255, alpha: 0.65)
}
