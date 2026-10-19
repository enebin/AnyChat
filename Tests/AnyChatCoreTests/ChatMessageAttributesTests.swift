import Foundation
import AnyChatCore
import XCTest

final class ChatMessageAttributesTests: XCTestCase {
    private struct Moderation: Hashable, Sendable {
        let isReported: Bool
    }

    private struct Pin: Hashable, Sendable {
        let pinnedBy: String
    }

    private struct Poll: Hashable, Sendable {
        let question: String
    }

    private enum Constant {
        static let messageID = "poll"
        static let date = Date(timeIntervalSince1970: 1_700_000_000)
        static let reported = Moderation(isReported: true)
        static let unreported = Moderation(isReported: false)
        static let pin = Pin(pinnedBy: "alice")
        static let poll = Poll(question: "Lunch?")
    }

    func testNewMessagesHaveNoAttributes() {
        // Given
        let message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, content: .text("Hi"))

        // When
        let moderation = message.attributes[Moderation.self]

        // Then
        XCTAssertNil(moderation)
        XCTAssertEqual(message.attributes, ChatMessage.Attributes())
    }

    func testRetrievesEachValueByItsTypeAlongsideCustomContent() {
        // Given
        var message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, customContent: Constant.poll)

        // When
        message.attributes[Moderation.self] = Constant.reported
        message.attributes[Pin.self] = Constant.pin

        // Then
        XCTAssertEqual(message.attributes[Moderation.self], Constant.reported)
        XCTAssertEqual(message.attributes[Pin.self], Constant.pin)
        XCTAssertNil(message.attributes[Poll.self])
        XCTAssertEqual(message.customContent?.value(as: Poll.self), Constant.poll)
    }

    func testAssigningReplacesTheValueOfTheSameTypeAndNilRemovesIt() {
        // Given
        var attributes = ChatMessage.Attributes()
        attributes[Moderation.self] = Constant.reported
        attributes[Pin.self] = Constant.pin

        // When
        attributes[Moderation.self] = Constant.unreported
        attributes[Pin.self] = nil

        // Then
        XCTAssertEqual(attributes[Moderation.self], Constant.unreported)
        XCTAssertNil(attributes[Pin.self])
    }

    func testEqualityAndHashingIncludeEveryTypeAndValueRegardlessOfOrder() {
        // Given
        var original = ChatMessage.Attributes()
        original[Moderation.self] = Constant.reported
        original[Pin.self] = Constant.pin
        var reordered = ChatMessage.Attributes()
        reordered[Pin.self] = Constant.pin
        reordered[Moderation.self] = Constant.reported
        var updated = original
        updated[Moderation.self] = Constant.unreported
        var fewer = original
        fewer[Pin.self] = nil

        // When
        let all = Set([original, reordered, updated, fewer])

        // Then
        XCTAssertEqual(original, reordered)
        XCTAssertEqual(original.hashValue, reordered.hashValue)
        XCTAssertNotEqual(original, updated)
        XCTAssertNotEqual(original, fewer)
        XCTAssertEqual(all.count, 3)
    }

    func testMessageEqualityIncludesAttributes() {
        // Given
        var original = ChatMessage(id: Constant.messageID, createdAt: Constant.date, customContent: Constant.poll)
        original.attributes[Moderation.self] = Constant.unreported
        var updated = original

        // When
        updated.attributes[Moderation.self] = Constant.reported

        // Then
        XCTAssertEqual(original.id, updated.id)
        XCTAssertEqual(original.customContent, updated.customContent)
        XCTAssertNotEqual(original, updated)
        XCTAssertEqual(Set([original, updated]).count, 2)
    }
}
