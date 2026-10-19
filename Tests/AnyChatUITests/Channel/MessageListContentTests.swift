import AnyChatCore
import XCTest
@testable import AnyChatUI

final class MessageListContentTests: XCTestCase {
    private enum Constant {
        static let me = "me"
        static let other = "alice"
        static let earlier = MessageFixtures.message("earlier", from: other)
        static let sentID = "sent"
    }

    func testNewPendingRowOfMineIsTheSentRow() {
        // Given
        let previous = content([Constant.earlier])
        let next = content([Constant.earlier, pending(Constant.sentID)])

        // When
        let sentRowID = next.sentRowID(after: previous)

        // Then
        XCTAssertEqual(sentRowID, Constant.sentID)
    }

    func testLastOfSeveralNewPendingRowsIsTheSentRow() {
        // Given
        let previous = content([Constant.earlier])
        let next = content([Constant.earlier, pending("first"), pending(Constant.sentID)])

        // When
        let sentRowID = next.sentRowID(after: previous)

        // Then
        XCTAssertEqual(sentRowID, Constant.sentID)
    }

    func testPendingRowAlreadyShownIsNotTheSentRow() {
        // Given
        let existing = pending(Constant.sentID)
        let previous = content([Constant.earlier, existing])
        let next = content([Constant.earlier, existing, MessageFixtures.message("reply", from: Constant.other)])

        // When
        let sentRowID = next.sentRowID(after: previous)

        // Then
        XCTAssertNil(sentRowID)
    }

    func testOthersRowAndSentRowOfMineAreNotTheSentRow() {
        // Given
        let previous = content([Constant.earlier])
        let next = content([
            Constant.earlier,
            MessageFixtures.message("other", from: Constant.other),
            MessageFixtures.message("mine-sent", from: Constant.me)
        ])

        // When
        let sentRowID = next.sentRowID(after: previous)

        // Then
        XCTAssertNil(sentRowID)
    }

    private func pending(_ id: String) -> ChatMessage {
        MessageFixtures.message(id, from: Constant.me, sendingStatus: .pending)
    }

    private func content(_ messages: [ChatMessage]) -> MessageListContent {
        MessageListContent(rows: MessageRowState.rows(for: messages, currentUserID: Constant.me, now: MessageFixtures.start))
    }
}
