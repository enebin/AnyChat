import XCTest
@testable import AnyChatUI

@MainActor
final class ComposerPresentationTests: XCTestCase {
    private enum Constant {
        static let hostPlaceholder = "Message…"
        static let defaultPlaceholder = "Enter message"
        static let unavailable = "Chat is unavailable in this channel"
        static let sentText = "Hello"
    }

    func testDefaultPlaceholderShowsWithoutAHostPlaceholder() {
        // Given
        let presentation = ComposerPresentation()

        // When
        let text = presentation.placeholderText

        // Then
        XCTAssertEqual(text, Constant.defaultPlaceholder)
    }

    func testHostPlaceholderReplacesTheDefaultWhetherOrNotTheComposerIsEnabled() {
        // Given
        let presentation = ComposerPresentation()
        presentation.placeholder = Constant.hostPlaceholder

        // When
        presentation.isEnabled = false
        let whileLoading = presentation.placeholderText
        presentation.isEnabled = true
        let whileSending = presentation.placeholderText

        // Then
        XCTAssertEqual(whileLoading, Constant.hostPlaceholder)
        XCTAssertEqual(whileSending, Constant.hostPlaceholder)
    }

    func testUnavailableTextWinsOverTheHostPlaceholder() {
        // Given
        let presentation = ComposerPresentation()
        presentation.placeholder = Constant.hostPlaceholder

        // When
        presentation.isUnavailable = true

        // Then
        XCTAssertEqual(presentation.placeholderText, Constant.unavailable)
    }

    func testSendShowsWhileEnabledWithADraft() {
        // Given
        let presentation = ComposerPresentation()
        presentation.isEnabled = true

        // When
        let withDraft = presentation.trailingControl(hasDraft: true)
        let withoutDraft = presentation.trailingControl(hasDraft: false)

        // Then
        XCTAssertEqual(withDraft, .send)
        XCTAssertEqual(withoutDraft, .items)
    }

    func testItemsShowWhileDisabledEvenWithADraft() {
        // Given
        let presentation = ComposerPresentation()
        presentation.isEnabled = false

        // When
        let control = presentation.trailingControl(hasDraft: true)

        // Then
        XCTAssertEqual(control, .items)
    }

    func testStopWinsWhileRespondingWhateverTheDraftAndEnabledState() {
        // Given
        let presentation = ComposerPresentation()
        presentation.isResponding = true

        // When
        presentation.isEnabled = true
        let enabledWithDraft = presentation.trailingControl(hasDraft: true)
        presentation.isEnabled = false
        let disabledWithoutDraft = presentation.trailingControl(hasDraft: false)

        // Then
        XCTAssertEqual(enabledWithDraft, .stop)
        XCTAssertEqual(disabledWithoutDraft, .stop)
    }

    func testContextPickersSetTheComposersFlags() {
        // Given
        let presentation = ComposerPresentation()
        presentation.isEnabled = true
        let context = presentation.context(showsAttachButton: false)

        // When
        context.openAttachmentMenu()
        context.openPhotoLibrary()
        context.openFiles()

        // Then
        XCTAssertTrue(presentation.isShowingMenu)
        XCTAssertTrue(presentation.isShowingPhotoLibrary)
        XCTAssertTrue(presentation.isShowingFiles)
    }

    func testContextPickersDoNothingWhileDisabled() {
        // Given
        let presentation = ComposerPresentation()
        presentation.isEnabled = false
        let context = presentation.context(showsAttachButton: false)

        // When
        context.openAttachmentMenu()
        context.openPhotoLibrary()
        context.openFiles()

        // Then
        XCTAssertFalse(presentation.isShowingMenu)
        XCTAssertFalse(presentation.isShowingPhotoLibrary)
        XCTAssertFalse(presentation.isShowingFiles)
    }

    func testContextCarriesTheCurrentStateAndActions() {
        // Given
        let presentation = ComposerPresentation()
        var sent: [String] = []
        var stops = 0
        presentation.onSend = { sent.append($0) }
        presentation.onStop = { stops += 1 }
        let before = presentation.context(showsAttachButton: false)

        // When
        presentation.isEnabled = true
        presentation.isUnavailable = true
        presentation.isResponding = true
        let after = presentation.context(showsAttachButton: false)
        after.send(text: " \(Constant.sentText) ")
        after.stop()

        // Then
        XCTAssertFalse(before.canSend)
        XCTAssertTrue(after.canSend)
        XCTAssertTrue(after.isUnavailable)
        XCTAssertTrue(after.isResponding)
        XCTAssertEqual(sent, [Constant.sentText])
        XCTAssertEqual(stops, 1)
    }
}
