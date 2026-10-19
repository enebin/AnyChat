import XCTest
@testable import AnyChatUI

@MainActor
final class MessageSwipeControllerTests: XCTestCase {
    private enum Constant {
        static let threshold: CGFloat = 60
        static let maxOffset: CGFloat = 90
    }

    /// Up to the threshold the row follows the finger exactly.
    func testOffsetFollowsTheFingerUpToTheThreshold() {
        XCTAssertEqual(MessageSwipeController.offset(forTravel: 0), 0)
        XCTAssertEqual(MessageSwipeController.offset(forTravel: 30), 30)
        XCTAssertEqual(MessageSwipeController.offset(forTravel: Constant.threshold), Constant.threshold)
    }

    /// Past the threshold the row moves a third as far as the finger and stops at its limit.
    func testOffsetResistsPastTheThresholdAndStopsAtItsLimit() {
        XCTAssertEqual(MessageSwipeController.offset(forTravel: Constant.threshold + 30), Constant.threshold + 10, accuracy: 0.001)
        XCTAssertEqual(MessageSwipeController.offset(forTravel: 1_000), Constant.maxOffset)
    }

    /// Travel toward the leading edge never moves the row.
    func testOffsetIgnoresTravelTowardTheLeadingEdge() {
        XCTAssertEqual(MessageSwipeController.offset(forTravel: -40), 0)
    }

    func testThresholdIsCrossedOnlyAtSixtyPoints() {
        XCTAssertFalse(MessageSwipeController.isPastThreshold(travel: Constant.threshold - 1))
        XCTAssertTrue(MessageSwipeController.isPastThreshold(travel: Constant.threshold))
        XCTAssertTrue(MessageSwipeController.isPastThreshold(travel: 500))
    }
}
