import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class MessageLongPressOverlayTests: XCTestCase {
    private let rows = MessageRowState.rows(
        for: [
            MessageFixtures.message("system", from: nil, .system("Alice joined")),
            MessageFixtures.message("text")
        ],
        currentUserID: "u1",
        now: MessageFixtures.start
    )

    func testOverlayStaysPresentableOnlyForAUserMessageInTheList() {
        XCTAssertEqual(MessageLongPressOverlay.presentableRow(id: "text", in: rows)?.id, "text")
        XCTAssertNil(MessageLongPressOverlay.presentableRow(id: "system", in: rows))
        XCTAssertNil(MessageLongPressOverlay.presentableRow(id: "removed", in: rows))
    }
}
