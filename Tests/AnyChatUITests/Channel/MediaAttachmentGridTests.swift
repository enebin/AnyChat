import SwiftUI
import XCTest
@testable import AnyChatUI

@MainActor
final class MediaAttachmentGridTests: XCTestCase {
    private enum Radius {
        static let outer: CGFloat = 12
        static let inner: CGFloat = 6
    }

    func testTwoCellsRoundTheirOuterSides() {
        // Given / When
        let leading = MediaAttachmentGrid.cornerRadii(index: 0, count: 2, isMine: false)
        let trailing = MediaAttachmentGrid.cornerRadii(index: 1, count: 2, isMine: false)

        // Then
        XCTAssertEqual(leading, radii(topLeading: Radius.outer, bottomLeading: Radius.outer))
        XCTAssertEqual(trailing, radii(bottomTrailing: Radius.outer, topTrailing: Radius.outer))
    }

    func testMiddleRowCellsUseTheInnerRadius() {
        // Given / When
        let cells = (2...3).map { MediaAttachmentGrid.cornerRadii(index: $0, count: 6, isMine: true) }

        // Then
        XCTAssertEqual(cells, [radii(), radii()])
    }

    func testFullLastRowRoundsTheBottomCorners() {
        // Given / When
        let leading = MediaAttachmentGrid.cornerRadii(index: 4, count: 6, isMine: false)
        let trailing = MediaAttachmentGrid.cornerRadii(index: 5, count: 6, isMine: false)

        // Then
        XCTAssertEqual(leading, radii(bottomLeading: Radius.outer))
        XCTAssertEqual(trailing, radii(bottomTrailing: Radius.outer))
    }

    /// An odd last cell sits on the sender's side and meets only that bottom corner.
    func testOddLastCellRoundsTheSendersBottomCorner() {
        // Given / When
        let incoming = MediaAttachmentGrid.cornerRadii(index: 2, count: 3, isMine: false)
        let outgoing = MediaAttachmentGrid.cornerRadii(index: 2, count: 3, isMine: true)

        // Then
        XCTAssertEqual(incoming, radii(bottomLeading: Radius.outer))
        XCTAssertEqual(outgoing, radii(bottomTrailing: Radius.outer))
    }

    func testFirstRowAboveAnOddLastCellKeepsSquareBottomCorners() {
        // Given / When
        let leading = MediaAttachmentGrid.cornerRadii(index: 0, count: 3, isMine: true)
        let trailing = MediaAttachmentGrid.cornerRadii(index: 1, count: 3, isMine: true)

        // Then
        XCTAssertEqual(leading, radii(topLeading: Radius.outer))
        XCTAssertEqual(trailing, radii(topTrailing: Radius.outer))
    }

    private func radii(
        topLeading: CGFloat = Radius.inner,
        bottomLeading: CGFloat = Radius.inner,
        bottomTrailing: CGFloat = Radius.inner,
        topTrailing: CGFloat = Radius.inner
    ) -> RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: topLeading,
            bottomLeading: bottomLeading,
            bottomTrailing: bottomTrailing,
            topTrailing: topTrailing
        )
    }
}
