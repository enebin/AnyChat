import UIKit
import XCTest
@testable import AnyChatDesignSystem

@MainActor
final class ChatIconTests: XCTestCase {
    func testEveryCaseResolvesToASystemSymbol() {
        // Given / When / Then
        for icon in ChatIcon.allCases {
            XCTAssertNotNil(icon.uiImage, icon.rawValue)
            XCTAssertTrue(icon.uiImage?.isSymbolImage == true, icon.rawValue)
        }
    }

    func testSwipeImageHasTheRequestedSizeAndTemplateRendering() {
        // Given
        let length: CGFloat = 24

        // When
        let image = ChatIcon.leave.redrawnUIImage(at: length)

        // Then
        XCTAssertEqual(image.size, CGSize(width: length, height: length))
        XCTAssertEqual(image.renderingMode, .alwaysTemplate)
    }
}
