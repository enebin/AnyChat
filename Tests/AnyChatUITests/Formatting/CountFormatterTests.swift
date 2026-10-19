import XCTest
@testable import AnyChatUI

final class CountFormatterTests: XCTestCase {
    /// Counts are abbreviated with K and M suffixes once they pass a thousand.
    func testUnitStringAbbreviatesLargeCounts() {
        // Given / When / Then
        XCTAssertEqual(CountFormatter.unitString(0), "0")
        XCTAssertEqual(CountFormatter.unitString(999), "999")
        XCTAssertEqual(CountFormatter.unitString(1_000), "1K")
        XCTAssertEqual(CountFormatter.unitString(3_200), "3.2K")
        XCTAssertEqual(CountFormatter.unitString(10_000), "10K")
        XCTAssertEqual(CountFormatter.unitString(1_500_000), "1.5M")
    }

    /// One-to-one and uncounted channels do not show a member count.
    func testMemberCountIsHiddenForOneToOneAndUncountedChannels() {
        // Given / When / Then
        XCTAssertNil(CountFormatter.memberCountText(nil))
        XCTAssertNil(CountFormatter.memberCountText(2))
        XCTAssertEqual(CountFormatter.memberCountText(3), "3")
    }

    /// The unread badge caps at 99+ and disappears at zero or when not counted.
    func testUnreadTextCapsAtNinetyNinePlus() {
        // Given / When / Then
        XCTAssertNil(CountFormatter.unreadText(nil))
        XCTAssertNil(CountFormatter.unreadText(0))
        XCTAssertEqual(CountFormatter.unreadText(1), "1")
        XCTAssertEqual(CountFormatter.unreadText(99), "99")
        XCTAssertEqual(CountFormatter.unreadText(100), "99+")
        XCTAssertEqual(CountFormatter.unreadText(1_000), "99+")
    }
}
