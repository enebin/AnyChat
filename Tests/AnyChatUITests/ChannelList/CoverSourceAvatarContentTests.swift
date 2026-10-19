import Foundation
import AnyChatDesignSystem
import XCTest
@testable import AnyChatUI

final class CoverSourceAvatarContentTests: XCTestCase {
    private enum Constant {
        static let coverURL = URL(string: "https://example.com/cover.png")!
        static let memberURL = URL(string: "https://example.com/a.png")!
    }

    /// A cover URL becomes a single picture.
    func testCoverURLBecomesASinglePicture() {
        // Given / When / Then
        XCTAssertEqual(Avatar.Content(.url(Constant.coverURL)), .image(Constant.coverURL))
    }

    /// Member pictures keep their order, and a member without one leaves a gap to fill.
    func testMemberAvatarsKeepTheirOrder() {
        // Given
        let cover = ChannelCover.members([
            .init(userID: "a", profileImageURL: Constant.memberURL),
            .init(userID: "b", profileImageURL: nil)
        ])

        // When / Then
        XCTAssertEqual(Avatar.Content(cover), .members([Constant.memberURL, nil]))
    }

    /// Broadcast and placeholder covers draw a glyph rather than a picture.
    func testGlyphCoversMapStraightAcross() {
        // Given / When / Then
        XCTAssertEqual(Avatar.Content(.broadcast), .broadcast)
        XCTAssertEqual(Avatar.Content(.placeholder), .placeholder)
    }
}
