import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class ComposerContextTests: XCTestCase {
    private enum Constant {
        static let text = "Hello"
        static let paddedText = "  Hello \n"
        static let blankText = " \n "
    }

    private var sent: [String] = []
    private var opened: [ComposerPicker] = []
    private var cancelledReplies = 0
    private var stops = 0

    func testSendTrimsTheTextWhileTheUserCanSend() {
        // Given
        let context = makeContext(canSend: true)

        // When
        context.send(text: Constant.paddedText)

        // Then
        XCTAssertEqual(sent, [Constant.text])
    }

    func testSendIgnoresBlankTextAndCallsWhileTheUserCannotSend() {
        // Given
        let enabled = makeContext(canSend: true)
        let disabled = makeContext(canSend: false)

        // When
        enabled.send(text: Constant.blankText)
        disabled.send(text: Constant.text)

        // Then
        XCTAssertEqual(sent, [])
    }

    func testOpenersReachTheirPickerWhileTheUserCanSend() {
        // Given
        let context = makeContext(canSend: true, canOpenCamera: true)

        // When
        context.openAttachmentMenu()
        context.openCamera()
        context.openPhotoLibrary()
        context.openFiles()

        // Then
        XCTAssertEqual(opened, [.menu, .camera, .photoLibrary, .files])
    }

    func testOpenersDoNothingWhileTheUserCannotSend() {
        // Given
        let context = makeContext(canSend: false, canOpenCamera: true)

        // When
        context.openAttachmentMenu()
        context.openCamera()
        context.openPhotoLibrary()
        context.openFiles()

        // Then
        XCTAssertEqual(opened, [])
    }

    func testCancelReplyClosesTheReplyOnlyWhileOneIsSet() {
        // Given
        let replying = makeContext(canSend: true, replyingTo: MessageFixtures.message("original"))
        let idle = makeContext(canSend: true)

        // When
        replying.cancelReply()
        idle.cancelReply()

        // Then
        XCTAssertEqual(cancelledReplies, 1)
        XCTAssertEqual(replying.replyingTo?.id, "original")
    }

    /// The Reducer reads the reply from the State, so sending while replying is the same call.
    func testSendWhileReplyingSendsTheText() {
        // Given
        let context = makeContext(canSend: true, replyingTo: MessageFixtures.message("original"))

        // When
        context.send(text: Constant.text)

        // Then
        XCTAssertEqual(sent, [Constant.text])
    }

    func testOpenCameraDoesNothingWithoutACamera() {
        // Given
        let context = makeContext(canSend: true, canOpenCamera: false)

        // When
        context.openCamera()

        // Then
        XCTAssertEqual(opened, [])
    }

    func testStopReachesTheHostWhileRespondingEvenWhenTheUserCannotSend() {
        // Given
        let context = makeContext(canSend: false, isResponding: true)

        // When
        context.stop()

        // Then
        XCTAssertEqual(stops, 1)
    }

    func testStopDoesNothingWhileNoResponseIsInProgress() {
        // Given
        let context = makeContext(canSend: true, isResponding: false)

        // When
        context.stop()

        // Then
        XCTAssertEqual(stops, 0)
    }

    /// A response in progress hides the default send button but does not block a host's send.
    func testSendStillWorksWhileResponding() {
        // Given
        let context = makeContext(canSend: true, isResponding: true)

        // When
        context.send(text: Constant.text)

        // Then
        XCTAssertEqual(sent, [Constant.text])
    }

    private func makeContext(
        canSend: Bool,
        canOpenCamera: Bool = false,
        replyingTo: ChatMessage? = nil,
        isResponding: Bool = false
    ) -> ComposerContext {
        ComposerContext(
            canSend: canSend,
            isUnavailable: false,
            canOpenCamera: canOpenCamera,
            replyingTo: replyingTo,
            isResponding: isResponding,
            showsAttachButton: true,
            theme: ChannelTheme(),
            send: { [unowned self] in sent.append($0) },
            open: { [unowned self] in opened.append($0) },
            cancelReply: { [unowned self] in cancelledReplies += 1 },
            stop: { [unowned self] in stops += 1 }
        )
    }
}
