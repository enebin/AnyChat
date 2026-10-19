import SwiftUI
import XCTest
@testable import AnyChatUI

final class DefaultThemeTests: XCTestCase {
    func testBuiltInThemesUseBlueAccentsAndWhiteOutgoingText() {
        // Given
        let themes: [(ChannelTheme, ChannelListTheme, UIUserInterfaceStyle)] = [
            (.light, .light, .light), (.dark, .dark, .dark),
            (.adaptive, .adaptive, .light), (.adaptive, .adaptive, .dark)
        ]

        for (channel, list, style) in themes {
            let traits = UITraitCollection(userInterfaceStyle: style)
            // The Messages kit's values from docs/design/messages/README.md.
            let blue = UIColor(red: 0, green: 136 / 255, blue: 1, alpha: 1)
            let gray = style == .dark
                ? UIColor(red: 38 / 255, green: 38 / 255, blue: 41 / 255, alpha: 1)
                : UIColor(red: 233 / 255, green: 233 / 255, blue: 234 / 255, alpha: 1)

            // When / Then
            XCTAssertEqual(UIColor(channel.outgoingBubbleBackground).resolvedColor(with: traits), blue)
            XCTAssertEqual(UIColor(channel.incomingBubbleBackground).resolvedColor(with: traits), gray)
            XCTAssertEqual(UIColor(channel.outgoingMessageText).resolvedColor(with: traits), UIColor(Color.white))
            XCTAssertEqual(UIColor(list.unreadBadgeBackground).resolvedColor(with: traits), blue)
            XCTAssertEqual(UIColor(list.unreadBadgeText).resolvedColor(with: traits), UIColor(Color.white))
            XCTAssertEqual(UIColor(list.barButtonTint).resolvedColor(with: traits), blue)
        }
    }

    func testOverlayDimIsTheMeasuredTintInEveryAppearance() {
        // Given: the design source's "Long-press overlay" dim.
        let dim = UIColor(red: 0, green: 0, blue: 25 / 255, alpha: 0.16)
        let themes: [(ChannelTheme, UIUserInterfaceStyle)] = [(.light, .light), (.dark, .dark), (.adaptive, .light), (.adaptive, .dark)]

        for (theme, style) in themes {
            // When
            let resolved = UIColor(theme.overlayDim).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))

            // Then
            var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var (er, eg, eb, ea): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            dim.getRed(&er, green: &eg, blue: &eb, alpha: &ea)
            XCTAssertEqual(r, er, accuracy: 0.002)
            XCTAssertEqual(g, eg, accuracy: 0.002)
            XCTAssertEqual(b, eb, accuracy: 0.002)
            XCTAssertEqual(a, ea, accuracy: 0.002)
        }
    }

    func testCursorFollowsAButtonTintGivenWithoutACursor() {
        // Given
        let custom: Color = .orange

        // When
        let followed = ChannelTheme(composerButtonTint: custom)
        let separate = ChannelTheme(composerButtonTint: custom, composerCursor: .green)

        // Then
        XCTAssertEqual(followed.composerCursor, custom)
        XCTAssertEqual(separate.composerCursor, .green)
    }

    func testExplicitThemeOverridesArePreserved() {
        // Given
        let custom: Color = .orange

        // When
        let channel = ChannelTheme(outgoingBubbleBackground: custom, messageFont: .title)
        let list = ChannelListTheme(barButtonTint: custom, titleFont: .title)

        // Then
        XCTAssertEqual(channel.outgoingBubbleBackground, custom)
        XCTAssertEqual(channel.messageFont, .title)
        XCTAssertEqual(list.barButtonTint, custom)
        XCTAssertEqual(list.titleFont, .title)
    }
}
