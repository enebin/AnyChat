import CoreGraphics
import XCTest
@testable import AnyChatUI

final class OverlayPlacementTests: XCTestCase {
    private enum Constant {
        /// From below the navigation bar to above the composer on a 402pt-wide screen.
        static let bounds = CGRect(x: 0, y: 100, width: 402, height: 700)
        static let bubble = CGRect(x: 16, y: 400, width: 100, height: 40)
        static let above = CGSize(width: 200, height: 50)
        static let card = CGSize(width: OverlayPlacement.cardWidth, height: 104)
        static let gap = OverlayPlacement.gap
        static let scale = OverlayPlacement.liftScale
        static let inset = OverlayPlacement.sideInset
    }

    private func place(
        bubble: CGRect = Constant.bubble,
        above: CGSize = Constant.above,
        card: CGSize = Constant.card,
        isMine: Bool = false,
        scalesBubble: Bool = true
    ) -> OverlayPlacement {
        OverlayPlacement(bubble: bubble, aboveSize: above, cardSize: card, bounds: Constant.bounds, isMine: isMine, scalesBubble: scalesBubble)
    }

    func testBubbleScalesFromItsTopSenderSideCornerWithViewsOnTheSenderSide() {
        // When
        let incoming = place()
        let mine = place(bubble: CGRect(x: 286, y: 400, width: 100, height: 40), isMine: true)

        // Then
        XCTAssertEqual(incoming.bubble, CGRect(x: 16, y: 400, width: 100 * Constant.scale, height: 40 * Constant.scale))
        XCTAssertEqual(incoming.above.minX, 16)
        XCTAssertEqual(incoming.card.minX, 16)
        XCTAssertEqual(incoming.above.maxY, 400 - Constant.gap)
        XCTAssertEqual(incoming.card.minY, incoming.bubble.maxY + Constant.gap, accuracy: 0.001)
        XCTAssertEqual(mine.bubble.maxX, 386, accuracy: 0.001)
        XCTAssertEqual(mine.above.maxX, 386, accuracy: 0.001)
        XCTAssertEqual(mine.card.maxX, 386, accuracy: 0.001)
    }

    func testWholeRowSlotIsNotScaled() {
        // When
        let placement = place(bubble: CGRect(x: 16, y: 400, width: 370, height: 60), scalesBubble: false)

        // Then
        XCTAssertEqual(placement.bubble, CGRect(x: 16, y: 400, width: 370, height: 60))
    }

    func testNoAboveViewLeavesNoGapAboveTheBubble() {
        // When
        let placement = place(above: .zero)

        // Then
        XCTAssertEqual(placement.bubble.minY, 400)
        XCTAssertEqual(placement.above.height, 0)
        XCTAssertEqual(placement.card.minY, placement.bubble.maxY + Constant.gap, accuracy: 0.001)
    }

    func testNoCardLeavesNoGapBelowTheBubble() {
        // When: the bubble sits at the bottom, so only its own height has to fit.
        let bottom = Constant.bounds.maxY - 40 * Constant.scale
        let placement = place(bubble: CGRect(x: 16, y: bottom, width: 100, height: 40), card: .zero)

        // Then
        XCTAssertEqual(placement.bubble.minY, bottom, accuracy: 0.001)
        XCTAssertEqual(placement.card.height, 0)
    }

    func testBubbleAtTheTopMovesTheGroupDownSoTheAboveViewFits() {
        // When
        let placement = place(bubble: CGRect(x: 16, y: 110, width: 100, height: 40))

        // Then
        XCTAssertEqual(placement.above.minY, Constant.bounds.minY)
        XCTAssertEqual(placement.bubble.minY, Constant.bounds.minY + Constant.above.height + Constant.gap)
    }

    func testBubbleAtTheBottomMovesTheGroupUpSoTheCardFits() {
        // When
        let placement = place(bubble: CGRect(x: 16, y: 770, width: 100, height: 40))

        // Then
        XCTAssertEqual(placement.card.maxY, Constant.bounds.maxY, accuracy: 0.001)
        XCTAssertEqual(placement.card.height, Constant.card.height)
        XCTAssertEqual(placement.visibleBubbleHeight, 40 * Constant.scale, accuracy: 0.001)
    }

    func testViewWiderThanItsSideSlidesInsideTheInsets() {
        // When: a bubble after a 26pt picture, with a view that would pass the trailing inset.
        let placement = place(bubble: CGRect(x: 54, y: 400, width: 100, height: 40), above: CGSize(width: 340, height: 50))

        // Then
        XCTAssertEqual(placement.above.maxX, Constant.bounds.maxX - Constant.inset)
        XCTAssertEqual(placement.card.minX, 54)
    }

    func testViewWiderThanTheScreenIsLimitedToTheInsets() {
        // When
        let placement = place(above: CGSize(width: 500, height: 50))

        // Then
        XCTAssertEqual(placement.above.minX, Constant.inset)
        XCTAssertEqual(placement.above.width, Constant.bounds.width - Constant.inset * 2)
    }

    func testBubbleTallerThanTheSpaceLeftIsCut() {
        // When
        let placement = place(bubble: CGRect(x: 16, y: 120, width: 240, height: 800))

        // Then
        let room = Constant.bounds.height - Constant.above.height - Constant.card.height - Constant.gap * 2
        XCTAssertEqual(placement.visibleBubbleHeight, room, accuracy: 0.001)
        XCTAssertEqual(placement.above.minY, Constant.bounds.minY)
        XCTAssertEqual(placement.card.maxY, Constant.bounds.maxY, accuracy: 0.001)
        XCTAssertEqual(placement.card.height, Constant.card.height)
    }

    func testViewsTallerThanTheScreenShortenTheCardSoItScrolls() {
        // When
        let placement = place(card: CGSize(width: OverlayPlacement.cardWidth, height: 1_000))

        // Then
        XCTAssertEqual(placement.visibleBubbleHeight, OverlayPlacement.minimumBubbleHeight)
        XCTAssertEqual(placement.above.minY, Constant.bounds.minY)
        XCTAssertEqual(placement.card.maxY, Constant.bounds.maxY, accuracy: 0.001)
        XCTAssertLessThan(placement.card.height, 1_000)
    }
}
