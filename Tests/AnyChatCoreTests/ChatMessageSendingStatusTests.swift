import Foundation
import AnyChatCore
import XCTest

final class ChatMessageSendingStatusTests: XCTestCase {
    private enum Constant {
        static let messageID = "message"
        static let date = Date(timeIntervalSince1970: 1_700_000_000)
        static let sender = ChatSender(id: "me", name: "Me")
        static let text = "Hello"
    }

    private func makeMessage() -> ChatMessage {
        ChatMessage(id: Constant.messageID, sender: Constant.sender, createdAt: Constant.date, content: .text(Constant.text))
    }

    func testNewMessageHasNoSendingStatus() {
        // Given / When
        let message = makeMessage()

        // Then
        XCTAssertNil(message.sendingStatus)
    }

    func testSendingStatusChangeMakesMessagesUnequal() {
        // Given
        let sent = makeMessage()
        var pending = makeMessage()

        // When
        pending.sendingStatus = .pending

        // Then
        XCTAssertNotEqual(sent, pending)
        XCTAssertNotEqual(sent.hashValue, pending.hashValue)
    }

    func testPendingAndFailedMessagesAreUnequal() {
        // Given
        var pending = makeMessage()
        var failed = makeMessage()

        // When
        pending.sendingStatus = .pending
        failed.sendingStatus = .failed

        // Then
        XCTAssertNotEqual(pending, failed)
    }

    func testChannelCanSendMessageByDefault() {
        // Given / When
        let channel = ChatChannel(id: "channel", createdAt: Constant.date)

        // Then
        XCTAssertTrue(channel.canSendMessage)
    }
}
