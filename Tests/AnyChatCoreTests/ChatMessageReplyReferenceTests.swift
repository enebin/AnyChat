import Foundation
import AnyChatCore
import XCTest

final class ChatMessageReplyReferenceTests: XCTestCase {
    private enum Constant {
        static let messageID = "reply"
        static let originalID = "original"
        static let date = Date(timeIntervalSince1970: 1_700_000_000)
        static let sender = ChatSender(id: "me", name: "Me")
        static let originalSender = ChatSender(id: "alice", name: "Alice")
        static let text = "Sounds good"
        static let originalText = "Lunch at noon?"
        static let editedText = "Lunch at one?"
    }

    private func makeMessage() -> ChatMessage {
        ChatMessage(id: Constant.messageID, sender: Constant.sender, createdAt: Constant.date, content: .text(Constant.text))
    }

    private func makeReference(text: String = Constant.originalText) -> ChatMessage.ReplyReference {
        ChatMessage.ReplyReference(messageID: Constant.originalID, sender: Constant.originalSender, content: .text(text))
    }

    func testNewMessageIsNotAReply() {
        // Given / When
        let message = makeMessage()

        // Then
        XCTAssertNil(message.replyTo)
    }

    func testReferenceToAnOriginalIsAvailable() {
        // Given / When
        let reference = makeReference()

        // Then
        XCTAssertFalse(reference.isUnavailable)
        XCTAssertEqual(reference.content, .text(Constant.originalText))
        XCTAssertEqual(reference.attachments, [])
    }

    func testUnavailableReferenceKeepsOnlyTheMessageID() {
        // Given / When
        let reference = ChatMessage.ReplyReference.unavailable(messageID: Constant.originalID)

        // Then
        XCTAssertTrue(reference.isUnavailable)
        XCTAssertEqual(reference.messageID, Constant.originalID)
        XCTAssertNil(reference.sender)
        XCTAssertEqual(reference.content, .text(""))
        XCTAssertEqual(reference.attachments, [])
    }

    func testReplyIsUnequalToTheSameMessageWithoutIt() {
        // Given
        let plain = makeMessage()
        var reply = makeMessage()

        // When
        reply.replyTo = makeReference()

        // Then
        XCTAssertNotEqual(plain, reply)
        XCTAssertNotEqual(plain.hashValue, reply.hashValue)
    }

    func testEditedOriginalChangesTheReply() {
        // Given
        var reply = makeMessage()
        reply.replyTo = makeReference()
        var updated = reply

        // When
        updated.replyTo = makeReference(text: Constant.editedText)

        // Then
        XCTAssertNotEqual(reply, updated)
    }

    func testDeletedOriginalChangesTheReply() {
        // Given
        var reply = makeMessage()
        reply.replyTo = makeReference()
        var updated = reply

        // When
        updated.replyTo = .unavailable(messageID: Constant.originalID)

        // Then
        XCTAssertNotEqual(reply, updated)
    }

    func testChannelDoesNotOfferRepliesByDefault() {
        // Given / When
        let channel = ChatChannel(id: "channel", createdAt: Constant.date)

        // Then
        XCTAssertFalse(channel.canReply)
    }
}
