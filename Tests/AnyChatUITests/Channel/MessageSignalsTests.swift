import SwiftUI
import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class MessageSignalsTests: XCTestCase {
    private let text = "Hello"
    private lazy var sent = MessageFixtures.message("sent", .text(text))
    private lazy var failed = MessageFixtures.message("failed", .text(text), sendingStatus: .failed)
    private lazy var pending = MessageFixtures.message("pending", .text(text), sendingStatus: .pending)
    private let attachmentOnly = MessageFixtures.message("files", .text(""))
    private let system = MessageFixtures.message("system", from: nil, .system("Alice joined"))

    // MARK: - Default items

    func testLongPressOnSentTextOffersCopy() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: sent, canSend: true, canReply: false), [.copy])
    }

    func testLongPressOnPendingTextOffersCopy() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: pending, canSend: true, canReply: false), [.copy])
    }

    func testLongPressOnFailedMessageOffersRetryAndRemoveWithoutCopy() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: failed, canSend: true, canReply: false), [.retry, .remove])
    }

    func testFailedTapOffersRetryAndRemove() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .failedTap, message: failed, canSend: true, canReply: false), [.retry, .remove])
    }

    func testFailedTapOffersOnlyRemoveWhileSendingIsOff() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .failedTap, message: failed, canSend: false, canReply: false), [.remove])
    }

    func testLongPressOnMessageWithoutTextOffersNothing() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: attachmentOnly, canSend: true, canReply: false), [])
    }

    /// Reply comes first on a long press, only while the message can be answered, and never in
    /// the failed-message dialog.
    func testLongPressOffersReplyFirstOnlyWhenTheMessageCanBeAnswered() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: sent, canSend: true, canReply: true), [.reply, .copy])
        XCTAssertEqual(MessageSignals.defaultItems(for: .longPress, message: attachmentOnly, canSend: true, canReply: true), [.reply])
        XCTAssertEqual(MessageSignals.defaultItems(for: .failedTap, message: failed, canSend: true, canReply: true), [.retry, .remove])
    }

    /// The context reflects the screen's rule, and `reply()` starts a reply only when it allows one.
    func testContextReplyFollowsTheScreensRule() {
        // Given
        var replied: [String] = []
        var signals = MessageSignals(canSend: true)
        signals.canReply = { $0 == "sent" }
        signals.reply = { replied.append($0) }
        let answerable = signals.context(for: .longPress, message: sent, isMine: false)
        let pendingContext = signals.context(for: .longPress, message: pending, isMine: true)

        // When
        answerable.reply()
        pendingContext.reply()

        // Then
        XCTAssertTrue(answerable.canReply)
        XCTAssertFalse(pendingContext.canReply)
        XCTAssertEqual(replied, ["sent"])
    }

    // MARK: - Overlay

    /// The overlay's context carries the long press's state and default items; its actions do not
    /// close the overlay, `dismiss()` does.
    func testOverlayContextCarriesTheLongPressStateAndClosesOnlyOnDismiss() {
        // Given
        var replied: [String] = []
        var dismissals = 0
        var signals = MessageSignals(canSend: true)
        signals.canReply = { _ in true }
        signals.reply = { replied.append($0) }
        let context = signals.overlayContext(for: sent, isMine: false) { dismissals += 1 }

        // When
        context.reply()

        // Then
        XCTAssertTrue(context.canReply)
        XCTAssertTrue(context.canCopy)
        XCTAssertFalse(context.canResend)
        XCTAssertFalse(context.defaultItemsAreEmpty)
        XCTAssertEqual(replied, ["sent"])
        XCTAssertEqual(dismissals, 0)

        // When
        context.dismiss()

        // Then
        XCTAssertEqual(dismissals, 1)
    }

    func testOverlayViewsOnlyWhileSetAndNeverForSystemMessages() {
        // Given
        var signals = MessageSignals()

        // Then
        XCTAssertNil(signals.overlayViews(for: sent, isMine: false))

        // When
        signals.overlay = .init(above: { _, _ in AnyView(Text("👍")) }, below: { _, _ in AnyView(EmptyView()) })

        // Then
        XCTAssertNotNil(signals.overlayViews(for: sent, isMine: false))
        XCTAssertNil(signals.overlayViews(for: system, isMine: false))
    }

    // MARK: - Content

    func testSystemMessageGetsNoSignalEvenWithAHostClosure() {
        // Given
        var signals = MessageSignals()
        signals.longPress = { _, _ in AnyView(Button("Report") {}) }

        // When
        let content = signals.content(for: .longPress, message: system, isMine: false)

        // Then
        XCTAssertNil(content)
    }

    func testFailedTapDoesNotApplyToAMessageThatDidNotFail() {
        // Given
        var signals = MessageSignals()
        signals.failedTap = { _, _ in AnyView(Button("Edit") {}) }

        // When
        let content = signals.content(for: .failedTap, message: sent, isMine: true)

        // Then
        XCTAssertNil(content)
    }

    func testEmptyDefaultHasNoContent() {
        XCTAssertNil(MessageSignals().content(for: .longPress, message: attachmentOnly, isMine: true))
    }

    func testHostLongPressReceivesTheMessageAndContextAndLeavesTheFailedTapDefault() {
        // Given
        var capturedMessage: ChatMessage?
        var capturedContext: MessageActionContext?
        var signals = MessageSignals(canSend: true)
        signals.longPress = { message, context in
            capturedMessage = message
            capturedContext = context
            return AnyView(EmptyView())
        }

        // When
        let longPress = signals.content(for: .longPress, message: failed, isMine: true)
        let failedTap = signals.content(for: .failedTap, message: failed, isMine: true)

        // Then
        XCTAssertNotNil(longPress)
        XCTAssertNotNil(failedTap)
        XCTAssertEqual(capturedMessage, failed)
        XCTAssertEqual(capturedContext?.isMine, true)
        XCTAssertEqual(capturedContext?.canResend, true)
        XCTAssertEqual(capturedContext?.canCopy, true)
    }

    // MARK: - Double tap

    func testDoubleTapHasNoActionWhileUnset() {
        XCTAssertNil(MessageSignals().doubleTapAction(for: sent, isMine: true))
    }

    func testDoubleTapSkipsSystemMessages() {
        // Given
        var signals = MessageSignals()
        signals.doubleTap = { _, _ in }

        // Then
        XCTAssertNil(signals.doubleTapAction(for: system, isMine: false))
    }

    func testDoubleTapCallsTheHostWithTheMessageAndContext() {
        // Given
        var capturedMessage: ChatMessage?
        var capturedContext: MessageActionContext?
        var signals = MessageSignals(canSend: true)
        signals.doubleTap = { message, context in
            capturedMessage = message
            capturedContext = context
        }

        // When
        signals.doubleTapAction(for: failed, isMine: true)?()

        // Then
        XCTAssertEqual(capturedMessage, failed)
        XCTAssertEqual(capturedContext?.canResend, true)
    }

    func testDoubleTapHasNoDefaultItems() {
        XCTAssertEqual(MessageSignals.defaultItems(for: .doubleTap, message: failed, canSend: true, canReply: false), [])
    }

    // MARK: - Context actions

    func testResendSendsTheFailedMessageIDWhileSendingIsOn() {
        // Given
        var resent: [String] = []
        let signals = MessageSignals(canSend: true, resend: { resent.append($0) })

        // When
        signals.context(for: .failedTap, message: failed, isMine: true).resend()

        // Then
        XCTAssertEqual(resent, [failed.id])
    }

    func testResendDoesNothingWhileSendingIsOff() {
        // Given
        var resent: [String] = []
        let signals = MessageSignals(canSend: false, resend: { resent.append($0) })

        // When
        let context = signals.context(for: .failedTap, message: failed, isMine: true)
        context.resend()

        // Then
        XCTAssertFalse(context.canResend)
        XCTAssertEqual(resent, [])
    }

    func testResendDoesNothingForAMessageThatDidNotFail() {
        // Given
        var resent: [String] = []
        let signals = MessageSignals(canSend: true, resend: { resent.append($0) })

        // When
        let context = signals.context(for: .longPress, message: sent, isMine: true)
        context.resend()

        // Then
        XCTAssertFalse(context.canResend)
        XCTAssertEqual(resent, [])
    }

    func testRemoveSendsTheMessageID() {
        // Given
        var removed: [String] = []
        let signals = MessageSignals(remove: { removed.append($0) })

        // When
        signals.context(for: .failedTap, message: failed, isMine: true).remove()

        // Then
        XCTAssertEqual(removed, [failed.id])
    }

    func testCannotCopyAMessageWithoutText() {
        XCTAssertFalse(MessageSignals().context(for: .longPress, message: attachmentOnly, isMine: true).canCopy)
    }
}
