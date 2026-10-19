import Foundation
import AnyChatCore
import XCTest

final class ChatMessageAttachmentTests: XCTestCase {
    private enum Constant {
        static let messageID = "message"
        static let date = Date(timeIntervalSince1970: 1_700_000_000)
        static let sender = ChatSender(id: "assistant", name: "Assistant")
        static let caption = "The photo and report"
        static let image = ChatAttachment(
            id: "image",
            kind: .image,
            url: URL(string: "https://example.com/photo.jpg")!,
            fileName: "photo.jpg",
            fileSize: 2_048,
            imageSize: .init(width: 640, height: 480)
        )
        static let document = ChatAttachment(
            id: "document",
            kind: .other,
            url: URL(string: "https://example.com/report.pdf")!,
            fileName: "report.pdf",
            fileSize: 1_024
        )
        static let attachments = [image, document]
    }

    private struct Summary: Hashable, Sendable {
        let text: String
    }

    func testMixedContentPreservesBodyAttachmentsAndMessageFields() {
        // Given
        let attachments = Constant.attachments

        // When
        let message = ChatMessage(
            id: Constant.messageID,
            sender: Constant.sender,
            createdAt: Constant.date,
            text: Constant.caption,
            attachments: attachments,
            receipt: .read
        )

        // Then
        XCTAssertEqual(message.id, Constant.messageID)
        XCTAssertEqual(message.sender, Constant.sender)
        XCTAssertEqual(message.createdAt, Constant.date)
        XCTAssertEqual(message.content, .text(Constant.caption))
        XCTAssertEqual(message.attachments, attachments)
        XCTAssertEqual(message.receipt, .read)
    }

    func testAttachmentOnlyMessageUsesAnEmptyTextBody() {
        // Given
        let attachments = Constant.attachments

        // When
        let message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, attachments: attachments)

        // Then
        XCTAssertEqual(message.content, .text(""))
        XCTAssertEqual(message.attachments, attachments)
    }

    func testTextOnlyMessageCanUseAnEmptyAttachmentList() {
        // Given
        let text = Constant.caption

        // When
        let message = ChatMessage(id: Constant.messageID, createdAt: Constant.date, text: text, attachments: [])

        // Then
        XCTAssertEqual(message.content, .text(text))
        XCTAssertTrue(message.attachments.isEmpty)
    }

    func testExistingInitializersKeepSystemAndCustomContentSeparate() {
        // Given
        let notice = "Channel renamed"
        let summary = Summary(text: Constant.caption)

        // When
        let system = ChatMessage(id: Constant.messageID, createdAt: Constant.date, content: .system(notice))
        let custom = ChatMessage(id: Constant.messageID, createdAt: Constant.date, customContent: summary)

        // Then
        XCTAssertEqual(system.content, .system(notice))
        XCTAssertTrue(system.attachments.isEmpty)
        XCTAssertEqual(custom.customContent?.value(as: Summary.self), summary)
        XCTAssertTrue(custom.attachments.isEmpty)
    }

    func testCustomContentCanAccompanyBodyAndAttachments() {
        // Given
        let summary = Summary(text: Constant.caption)

        // When
        let message = ChatMessage(
            id: Constant.messageID,
            sender: Constant.sender,
            createdAt: Constant.date,
            text: Constant.caption,
            attachments: Constant.attachments,
            customContent: summary,
            receipt: .delivered
        )

        // Then
        XCTAssertEqual(message.content, .text(Constant.caption))
        XCTAssertEqual(message.attachments, Constant.attachments)
        XCTAssertEqual(message.customContent?.value(as: Summary.self), summary)
        XCTAssertEqual(message.sender, Constant.sender)
        XCTAssertEqual(message.receipt, .delivered)
    }

    func testAttachmentMetadataAndOrderParticipateInMessageEqualityAndHashing() {
        // Given
        let original = ChatMessage(
            id: Constant.messageID, createdAt: Constant.date, text: Constant.caption, attachments: Constant.attachments
        )
        var updated = original
        updated.attachments[0].imageSize?.width = 1_280
        var reordered = original
        reordered.attachments.reverse()

        // When
        let messages = Set([original, original, updated, reordered])

        // Then
        XCTAssertEqual(messages.count, 3)
        XCTAssertNotEqual(original, updated)
        XCTAssertNotEqual(original, reordered)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.content, original.content)
    }
}
