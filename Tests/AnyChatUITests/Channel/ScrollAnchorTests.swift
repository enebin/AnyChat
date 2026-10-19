import CoreGraphics
import XCTest
@testable import AnyChatUI

final class ScrollAnchorTests: XCTestCase {
    private enum Constant {
        static let rowID = "anchor"
        static let geometry = ScrollAnchor.Geometry(
            offset: 200,
            viewportHeight: 500,
            contentHeight: 1_000,
            topInset: 40,
            bottomInset: 20
        )
        static let rowMinY: CGFloat = 180
        static let addedHeight: CGFloat = 300
        static let sentRowHeight: CGFloat = 60
        static let keyboardHeight: CGFloat = 250
    }

    func testGeometryIncludesAdjustedInsets() {
        // Given
        let geometry = Constant.geometry

        // When
        let minimum = geometry.minOffset
        let maximum = geometry.maxOffset
        let visibleTop = geometry.visibleTop
        let distanceToTop = geometry.distanceToTop

        // Then
        XCTAssertEqual(minimum, -40)
        XCTAssertEqual(maximum, 520)
        XCTAssertEqual(visibleTop, 240)
        XCTAssertEqual(distanceToTop, 240)
    }

    func testShortContentHasOnlyOneRestingOffset() {
        // Given
        var geometry = Constant.geometry
        geometry.contentHeight = 100

        // When
        let maximum = geometry.maxOffset
        let offset = geometry.clamped(geometry.offset)

        // Then
        XCTAssertEqual(maximum, geometry.minOffset)
        XCTAssertEqual(offset, geometry.minOffset)
    }

    func testBottomToleranceIncludesBoundaryAndOverscroll() {
        // Given
        var geometry = Constant.geometry
        let maximum = geometry.maxOffset

        // When
        geometry.offset = maximum - ScrollAnchor.bottomTolerance
        let atBoundary = geometry.isAtBottom
        geometry.offset -= 1
        let outsideBoundary = geometry.isAtBottom
        geometry.offset = maximum + 1
        let overscrolled = geometry.isAtBottom

        // Then
        XCTAssertTrue(atBoundary)
        XCTAssertFalse(outsideBoundary)
        XCTAssertTrue(overscrolled)
    }

    func testAwayFromBottomOnlyPastTheJumpToLatestDistance() {
        // Given
        var geometry = Constant.geometry
        let maximum = geometry.maxOffset

        // When
        geometry.offset = maximum
        let atBottom = geometry.isAwayFromBottom
        geometry.offset = maximum - ScrollAnchor.awayFromBottomDistance
        let atDistance = geometry.isAwayFromBottom
        geometry.offset -= 1
        let pastDistance = geometry.isAwayFromBottom

        // Then
        XCTAssertFalse(atBottom)
        XCTAssertFalse(atDistance)
        XCTAssertTrue(pastDistance)
    }

    func testShortContentIsNeverAwayFromBottom() {
        // Given
        var geometry = Constant.geometry
        geometry.contentHeight = 100

        // When
        geometry.offset = geometry.minOffset
        let isAway = geometry.isAwayFromBottom

        // Then
        XCTAssertFalse(isAway)
    }

    func testPinnedListCapturesBottomDespiteVisibleRow() {
        // Given
        let geometry = Constant.geometry

        // When
        let anchor = ScrollAnchor.capture(
            geometry,
            isPinnedToBottom: true,
            firstVisibleRow: (Constant.rowID, Constant.rowMinY)
        )

        // Then
        XCTAssertEqual(anchor, .bottom)
    }

    func testUnpinnedListCapturesPartiallyVisibleRow() {
        // Given
        let geometry = Constant.geometry

        // When
        let anchor = captureRow(in: geometry)

        // Then
        XCTAssertEqual(anchor, .row(id: Constant.rowID, distanceFromViewportTop: -20))
    }

    func testMissingVisibleRowCapturesBottom() {
        // Given
        let geometry = Constant.geometry

        // When
        let anchor = ScrollAnchor.capture(geometry, isPinnedToBottom: false, firstVisibleRow: nil)

        // Then
        XCTAssertEqual(anchor, .bottom)
    }

    func testPrependingContentKeepsRowAtSameScreenPosition() {
        // Given
        let previous = Constant.geometry
        let anchor = captureRow(in: previous)
        var next = previous
        next.contentHeight += Constant.addedHeight
        let rowMinY = Constant.rowMinY + Constant.addedHeight

        // When
        let offset = anchor.restoredOffset(in: next, rowMinY: rowMinY)

        // Then
        XCTAssertEqual(rowMinY - offset, Constant.rowMinY - previous.offset)
        XCTAssertEqual(offset, previous.offset + Constant.addedHeight)
    }

    func testAppendingContentDoesNotMoveUnpinnedRow() {
        // Given
        let previous = Constant.geometry
        let anchor = captureRow(in: previous)
        var next = previous
        next.contentHeight += Constant.addedHeight

        // When
        let offset = anchor.restoredOffset(in: next, rowMinY: Constant.rowMinY)

        // Then
        XCTAssertEqual(offset, previous.offset)
    }

    func testBottomAnchorFollowsGrowingContent() {
        // Given
        var geometry = Constant.geometry
        let previousBottom = geometry.maxOffset
        geometry.contentHeight += Constant.addedHeight

        // When
        let offset = ScrollAnchor.bottom.restoredOffset(in: geometry, rowMinY: nil)

        // Then
        XCTAssertEqual(offset, previousBottom + Constant.addedHeight)
    }

    func testDeletedAnchorKeepsCurrentOffsetWithinBounds() {
        // Given
        let geometry = Constant.geometry
        let anchor = captureRow(in: geometry)

        // When
        let offset = anchor.restoredOffset(in: geometry, rowMinY: nil)

        // Then
        XCTAssertEqual(offset, geometry.offset)
    }

    func testDeletedAnchorClampsOffsetAfterContentShrinks() {
        // Given
        var geometry = Constant.geometry
        let anchor = captureRow(in: geometry)
        geometry.contentHeight = 600

        // When
        let offset = anchor.restoredOffset(in: geometry, rowMinY: nil)

        // Then
        XCTAssertEqual(offset, geometry.maxOffset)
    }

    func testRestoredRowCannotScrollPastEitherBoundary() {
        // Given
        let geometry = Constant.geometry
        let anchor = captureRow(in: geometry)

        // When
        let aboveTop = anchor.restoredOffset(in: geometry, rowMinY: -100)
        let belowBottom = anchor.restoredOffset(in: geometry, rowMinY: geometry.contentHeight)

        // Then
        XCTAssertEqual(aboveTop, geometry.minOffset)
        XCTAssertEqual(belowBottom, geometry.maxOffset)
    }

    // MARK: - Question to top

    func testSentRowAtTopSitsTheSpacingBelowTheVisibleTop() {
        // Given
        let geometry = Constant.geometry

        // When
        let anchor = ScrollAnchor.sentRowAtTop(id: Constant.rowID, in: geometry)

        // Then
        XCTAssertEqual(anchor, .row(
            id: Constant.rowID,
            distanceFromViewportTop: geometry.topInset + ScrollAnchor.sentRowTopSpacing
        ))
    }

    func testSpaceLetsTheLastRowReachTheTop() {
        // Given
        let geometry = Constant.geometry
        let rowMinY = geometry.contentHeight - Constant.sentRowHeight

        // When
        let space = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // Then
        var spaced = geometry
        spaced.bottomInset += space
        let offset = ScrollAnchor.sentRowAtTop(id: Constant.rowID, in: geometry)
            .restoredOffset(in: spaced, rowMinY: rowMinY)
        XCTAssertEqual(space, 364)
        XCTAssertEqual(offset, spaced.maxOffset)
        XCTAssertEqual(rowMinY - offset, geometry.topInset + ScrollAnchor.sentRowTopSpacing)
    }

    func testShortContentGetsSpaceUpToTheVisibleBottom() {
        // Given
        var geometry = Constant.geometry
        geometry.contentHeight = 200
        let rowMinY: CGFloat = 120

        // When
        let space = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // Then
        XCTAssertEqual(space, 344)
        var spaced = geometry
        spaced.bottomInset += space
        XCTAssertEqual(rowMinY - ScrollAnchor.sentRowTopSpacing - geometry.topInset, spaced.maxOffset)
    }

    func testGrowingAnswerShrinksTheSpaceUntilItFillsTheScreen() {
        // Given
        var geometry = Constant.geometry
        let rowMinY = geometry.contentHeight - Constant.sentRowHeight
        let before = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // When
        geometry.contentHeight += Constant.addedHeight
        let grown = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)
        geometry.contentHeight += before
        let filled = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // Then
        XCTAssertEqual(grown, before - Constant.addedHeight)
        XCTAssertEqual(filled, 0)
    }

    func testKeyboardShrinksTheSpaceByItsHeight() {
        // Given
        var geometry = Constant.geometry
        let rowMinY = geometry.contentHeight - Constant.sentRowHeight
        let before = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // When
        geometry.bottomInset += Constant.keyboardHeight
        let withKeyboard = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // Then
        XCTAssertEqual(withKeyboard, before - Constant.keyboardHeight)
    }

    func testOlderPageAboveKeepsTheSpace() {
        // Given
        var geometry = Constant.geometry
        let rowMinY = geometry.contentHeight - Constant.sentRowHeight
        let before = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY, toTopOf: geometry)

        // When
        geometry.contentHeight += Constant.addedHeight
        let after = ScrollAnchor.spaceBelowContent(bringingRowAt: rowMinY + Constant.addedHeight, toTopOf: geometry)

        // Then
        XCTAssertEqual(after, before)
    }

    func testRowWithAScreenOfContentBelowNeedsNoSpace() {
        // Given
        let geometry = Constant.geometry

        // When
        let space = ScrollAnchor.spaceBelowContent(bringingRowAt: Constant.rowMinY, toTopOf: geometry)

        // Then
        XCTAssertEqual(space, 0)
    }

    private func captureRow(in geometry: ScrollAnchor.Geometry) -> ScrollAnchor {
        ScrollAnchor.capture(
            geometry,
            isPinnedToBottom: false,
            firstVisibleRow: (Constant.rowID, Constant.rowMinY)
        )
    }
}
