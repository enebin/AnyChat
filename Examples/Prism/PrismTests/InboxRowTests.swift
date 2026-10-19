import XCTest
import AnyChatUI
@testable import Prism

@MainActor
final class InboxRowTests: XCTestCase {
    private let currentUser = PrismBackend.me
    private let friend = ChatSender(id: "friend", name: "Alex Kim")
    private let date = Date(timeIntervalSince1970: 0)
    private let messageID = "message"
    private let text = "Hello"
    private let attachmentURL = URL(fileURLWithPath: "/tmp/attachment")
    private let attachmentCases: [(ChatMessage.FileKind, String)] = [
        (.image, "a photo"), (.gif, "a GIF"), (.video, "a video"),
        (.audio, "an audio file"), (.voice, "a voice message"), (.other, "a file")
    ]

    func testSingleAttachmentPreviewUsesItsKindForBothSenders() {
        // Given
        for (kind, description) in attachmentCases {
            for sender in [currentUser, friend] {
                let message = makeMessage(sender: sender, kinds: [kind])

                // When
                let preview = InboxRow(channel: channel(message: message)).preview

                // Then
                let prefix = sender == currentUser ? "You sent " : "Sent "
                XCTAssertEqual(preview, prefix + description, "\(kind), sender: \(sender.id)")
            }
        }
    }

    func testLegacyFilePreviewUsesItsKind() {
        // Given
        for (kind, description) in attachmentCases {
            let message = ChatMessage(id: messageID, sender: currentUser, createdAt: date, content: .file(kind))

            // When
            let preview = InboxRow(channel: channel(message: message)).preview

            // Then
            XCTAssertEqual(preview, "You sent " + description, "\(kind)")
        }
    }

    func testMultipleAttachmentsUsePluralPreviewForBothSenders() {
        // Given
        let attachmentGroups: [[ChatMessage.FileKind]] = [[.image, .video], [.other, .other], [.image, .image]]
        for kinds in attachmentGroups {
            for sender in [currentUser, friend] {
                let message = makeMessage(sender: sender, kinds: kinds)

                // When
                let preview = InboxRow(channel: channel(message: message)).preview

                // Then
                XCTAssertEqual(preview, sender == currentUser ? "You sent files" : "Sent files")
            }
        }
    }

    func testLegacyMultipleFilesWithoutMetadataUsePluralPreview() {
        // Given
        let message = ChatMessage(id: messageID, sender: friend, createdAt: date, content: .files)

        // When
        let preview = InboxRow(channel: channel(message: message)).preview

        // Then
        XCTAssertEqual(preview, "Sent files")
    }

    func testCaptionedAttachmentStillUsesAttachmentPreview() {
        // Given
        var message = makeMessage(sender: currentUser, kinds: [.video])
        message.content = .text(text)

        // When
        let preview = InboxRow(channel: channel(message: message)).preview

        // Then
        XCTAssertEqual(preview, "You sent a video")
    }

    func testTypingTakesPrecedenceOverAttachmentPreview() {
        // Given
        let message = makeMessage(sender: currentUser, kinds: [.other])
        var channel = channel(message: message)
        channel.typingUsers = [friend]

        // When
        let preview = InboxRow(channel: channel).preview

        // Then
        XCTAssertEqual(preview, "typing...")
    }

    func testTextAndReadReceiptPreviewsStayUnchanged() {
        // Given
        var message = ChatMessage(id: messageID, sender: currentUser, createdAt: date, content: .text(text))
        let unreadChannel = channel(message: message)
        message.receipt = .read
        let readChannel = channel(message: message)

        // When
        let unreadPreview = InboxRow(channel: unreadChannel).preview
        let readPreview = InboxRow(channel: readChannel).preview

        // Then
        XCTAssertEqual(unreadPreview, "You: \(text)")
        XCTAssertEqual(readPreview, "Seen by Alex")
    }

    private func makeMessage(sender: ChatSender, kinds: [ChatMessage.FileKind]) -> ChatMessage {
        ChatMessage(
            id: messageID,
            sender: sender,
            createdAt: date,
            attachments: kinds.enumerated().map { index, kind in
                ChatAttachment(id: "attachment-\(index)", kind: kind, url: attachmentURL)
            }
        )
    }

    private func channel(message: ChatMessage) -> ChatChannel {
        ChatChannel(id: "channel", createdAt: date, members: [currentUser, friend], lastMessage: message)
    }
}
