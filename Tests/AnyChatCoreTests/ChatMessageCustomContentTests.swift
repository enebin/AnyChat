import Foundation
import AnyChatCore
import XCTest

final class ChatMessageCustomContentTests: XCTestCase {
    private struct Thinking: Hashable, Sendable {
        let text: String
    }

    private struct Response: Hashable, Sendable {
        let text: String
    }

    private enum Constant {
        static let messageID = "reply"
        static let date = Date(timeIntervalSince1970: 1_700_000_000)
        static let text = "Working"
        static let updatedText = "Finished"
        static let sender = ChatSender(id: "assistant")
    }

    func testRetrievesTheOriginalTypeAndRejectsOtherTypes() {
        // Given
        let value = Thinking(text: Constant.text)
        let content = ChatMessage.CustomContent(value)

        // When
        let thinking = content.value(as: Thinking.self)
        let response = content.value(as: Response.self)

        // Then
        XCTAssertEqual(thinking, value)
        XCTAssertNil(response)
    }

    func testEqualityAndHashingIncludeTheValueAndConcreteType() {
        // Given
        let original = ChatMessage.CustomContent(Thinking(text: Constant.text))
        let equal = ChatMessage.CustomContent(Thinking(text: Constant.text))
        let updated = ChatMessage.CustomContent(Thinking(text: Constant.updatedText))
        let otherType = ChatMessage.CustomContent(Response(text: Constant.text))

        // When
        let contents = Set([original, equal, updated, otherType])

        // Then
        XCTAssertEqual(original, equal)
        XCTAssertEqual(original.hashValue, equal.hashValue)
        XCTAssertNotEqual(original, updated)
        XCTAssertNotEqual(original, otherType)
        XCTAssertEqual(contents.count, 3)
    }

    func testNumericConversionsDoNotEraseTheConcreteType() {
        // Given
        let integer = ChatMessage.CustomContent(Int(1))
        let floatingPoint = ChatMessage.CustomContent(Double(1))

        // When
        let converted = integer.value(as: Double.self)

        // Then
        XCTAssertNotEqual(integer, floatingPoint)
        XCTAssertNil(converted)
    }

    func testCustomInitializerPreservesFallbackAndMessageFields() {
        // Given
        let value = Thinking(text: Constant.text)
        let fallback = ChatMessage.Content.text(Constant.text)

        // When
        let message = ChatMessage(
            id: Constant.messageID,
            sender: Constant.sender,
            createdAt: Constant.date,
            content: fallback,
            customContent: value,
            receipt: .read
        )

        // Then
        XCTAssertEqual(message.id, Constant.messageID)
        XCTAssertEqual(message.sender, Constant.sender)
        XCTAssertEqual(message.createdAt, Constant.date)
        XCTAssertEqual(message.content, fallback)
        XCTAssertEqual(message.customContent?.value(as: Thinking.self), value)
        XCTAssertEqual(message.receipt, .read)
    }

    func testUnregisteredCustomContentDefaultsToUnsupportedFallback() {
        // Given
        let value = Thinking(text: Constant.text)

        // When
        let message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, customContent: value)

        // Then
        XCTAssertEqual(message.content, .unsupported)
        XCTAssertEqual(message.customContent?.value(as: Thinking.self), value)
    }

    func testOrdinaryMessagesHaveNoCustomContent() {
        // Given
        let fallback = ChatMessage.Content.text(Constant.text)

        // When
        let message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, content: fallback)

        // Then
        XCTAssertNil(message.customContent)
        XCTAssertEqual(message.content, fallback)
    }
}
