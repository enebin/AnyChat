import SwiftUI
import XCTest
@testable import AnyChatDesignSystem

final class ChatTypographyTests: XCTestCase {
    func testTypographyUsesDynamicTypeTextStyles() {
        // Given
        let styles: [(Font, Font)] = [
            (ChatTypography.headline, .headline),
            (ChatTypography.body, .body),
            (ChatTypography.button, .subheadline.weight(.semibold)),
            (ChatTypography.caption, .caption),
            (ChatTypography.captionEmphasized, .caption.weight(.semibold)),
            (ChatTypography.caption2, .caption2)
        ]

        // When / Then
        for (actual, expected) in styles {
            XCTAssertEqual(actual, expected)
        }
    }
}
