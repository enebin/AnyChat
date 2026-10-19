import AnyChatCore
import XCTest
@testable import AnyChatUI

final class MessagePreviewFormatterTests: XCTestCase {
    private enum Constant {
        static let typingEnabled = ChannelListOptions(isTypingIndicatorEnabled: true)
        static let typingDisabled = ChannelListOptions(isTypingIndicatorEnabled: false)
        static let alice = ChatSender(id: "u1", name: "Alice")
        static let bob = ChatSender(id: "u2", name: "Bob")
        static let carol = ChatSender(id: "u3", name: "Carol")
    }

    /// A text message shows its text and truncates at the end.
    func testTextMessageShowsItsText() {
        // Given
        let channel = ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(.text("See you tomorrow")) }

        // When
        let preview = MessagePreviewFormatter.preview(for: channel, options: Constant.typingDisabled)

        // Then
        XCTAssertEqual(preview, .init(text: "See you tomorrow", truncation: .tail))
    }

    /// A system message shows its text and truncates in the middle.
    func testSystemMessageTruncatesInTheMiddle() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.lastMessage = ChannelFixtures.message(.system("Alice joined"), senderID: nil)
        }

        // When
        let preview = MessagePreviewFormatter.preview(for: channel, options: Constant.typingDisabled)

        // Then
        XCTAssertEqual(preview, .init(text: "Alice joined", truncation: .middle))
    }

    /// A channel with no messages, or an unsupported one, shows nothing.
    func testMissingOrUnsupportedMessageShowsEmptyPreview() {
        // Given
        let empty = ChannelFixtures.channel()
        let unsupported = ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(.unsupported) }

        // When / Then
        XCTAssertEqual(MessagePreviewFormatter.preview(for: empty, options: Constant.typingDisabled).text, "")
        XCTAssertEqual(MessagePreviewFormatter.preview(for: unsupported, options: Constant.typingDisabled).text, "")
    }

    /// Each file kind maps to its own word.
    func testFileKindsMapToPreviewWords() {
        // Given / When / Then
        XCTAssertEqual(MessagePreviewFormatter.text(for: .image), MessagePreviewFormatter.photo)
        XCTAssertEqual(MessagePreviewFormatter.text(for: .gif), MessagePreviewFormatter.gif)
        XCTAssertEqual(MessagePreviewFormatter.text(for: .video), MessagePreviewFormatter.video)
        XCTAssertEqual(MessagePreviewFormatter.text(for: .audio), MessagePreviewFormatter.audio)
        XCTAssertEqual(MessagePreviewFormatter.text(for: .voice), MessagePreviewFormatter.voice)
        XCTAssertEqual(MessagePreviewFormatter.text(for: .other), MessagePreviewFormatter.file)
    }

    /// File previews use the file word and truncate in the middle.
    func testFileMessagesUseFileWords() {
        // Given
        let single = ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(.file(.video)) }
        let multiple = ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(.files) }

        // When / Then
        XCTAssertEqual(
            MessagePreviewFormatter.preview(for: single, options: Constant.typingDisabled),
            .init(text: MessagePreviewFormatter.video, truncation: .middle)
        )
        XCTAssertEqual(
            MessagePreviewFormatter.preview(for: multiple, options: Constant.typingDisabled),
            .init(text: MessagePreviewFormatter.multipleFiles, truncation: .middle)
        )
    }

    func testMixedContentPreviewPrefersTheTextBody() {
        // Given
        let body = "The photo and report"
        let message = ChatMessage(
            id: "mixed", createdAt: MessageFixtures.start, text: body,
            attachments: [AttachmentFixtures.image, AttachmentFixtures.document]
        )

        // When
        let preview = MessagePreviewFormatter.lastMessagePreview(for: message)

        // Then
        XCTAssertEqual(preview, .init(text: body, truncation: .tail))
    }

    func testAttachmentOnlyPreviewUsesTheFileKindOrMultipleFileLabel() {
        // Given
        let image = ChatMessage(id: "image", createdAt: MessageFixtures.start, attachments: [AttachmentFixtures.image])
        let document = ChatMessage(id: "document", createdAt: MessageFixtures.start, attachments: [AttachmentFixtures.document])
        let multiple = ChatMessage(
            id: "multiple", createdAt: MessageFixtures.start,
            attachments: [AttachmentFixtures.image, AttachmentFixtures.document]
        )

        // When
        let previews = [image, document, multiple].map { MessagePreviewFormatter.lastMessagePreview(for: $0) }

        // Then
        XCTAssertEqual(previews, [
            .init(text: MessagePreviewFormatter.photo, truncation: .middle),
            .init(text: MessagePreviewFormatter.file, truncation: .middle),
            .init(text: MessagePreviewFormatter.multipleFiles, truncation: .middle)
        ])
    }

    func testEmptyBodyAndAttachmentsProduceAnEmptyPreview() {
        // Given
        let message = ChatMessage(id: "empty", createdAt: MessageFixtures.start, text: "", attachments: [])

        // When
        let preview = MessagePreviewFormatter.lastMessagePreview(for: message)

        // Then
        XCTAssertEqual(preview, .init(text: "", truncation: .tail))
    }

    /// Someone typing replaces the last message, but only while the option is on.
    func testTypingReplacesPreviewOnlyWhenEnabled() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.lastMessage = ChannelFixtures.message(.text("Hello"))
            $0.typingUsers = [Constant.alice]
        }

        // When / Then
        XCTAssertEqual(
            MessagePreviewFormatter.preview(for: channel, options: Constant.typingEnabled),
            .init(text: "Alice is typing...", truncation: .tail)
        )
        XCTAssertEqual(MessagePreviewFormatter.preview(for: channel, options: Constant.typingDisabled).text, "Hello")
    }

    /// The typing sentence changes shape with the number of people typing.
    func testTypingTextChangesWithParticipantCount() {
        // Given / When / Then
        XCTAssertEqual(MessagePreviewFormatter.typingText(for: [Constant.alice]), "Alice is typing...")
        XCTAssertEqual(
            MessagePreviewFormatter.typingText(for: [Constant.alice, Constant.bob]),
            "Alice and Bob are typing..."
        )
        XCTAssertEqual(
            MessagePreviewFormatter.typingText(for: [Constant.alice, Constant.bob, Constant.carol]),
            "Several people are typing..."
        )
    }

    /// A user without a name is called out generically while typing.
    func testTypingTextFallsBackForUserWithoutName() {
        // Given
        let anonymous = ChatSender(id: "u1")

        // When
        let text = MessagePreviewFormatter.typingText(for: [anonymous])

        // Then
        XCTAssertEqual(text, "\(MessagePreviewFormatter.unnamedTypingMember) is typing...")
    }
}
