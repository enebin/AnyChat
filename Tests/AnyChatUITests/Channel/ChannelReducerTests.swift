import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ChannelReducerTests: XCTestCase {
    private typealias Decision = ChannelReducer.Decision

    private enum Constant {
        static let message = "Something broke"
        static let a = MessageFixtures.message("a")
        static let b = MessageFixtures.message("b")
        static let text = "Hi there"
        static let pending = MessageFixtures.message("pending", from: "me", sendingStatus: .pending)
        static let failed = MessageFixtures.message("failed", from: "me", sendingStatus: .failed)
        static let unknownID = "unknown"
        static let system = MessageFixtures.message("system", from: nil, .system("Bob joined"))
        /// Phases where the list is not on screen.
        static let hiddenPhases: [ChannelState.Phase] = [.idle, .loading, .error("Earlier")]
    }

    // MARK: - start / retry

    /// The first start shows a spinner and opens an observation.
    func testStartFromIdleBeginsObserving() {
        // Given
        let state = ChannelState()

        // When
        let decision = reduce(state, .start)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loading)
        XCTAssertEqual(decision.effects, [.startObserving])
    }

    /// Coming back to a screen that already started must not reload it.
    func testStartIsIgnoredOnceStarted() {
        // Given
        let states = [withPhase(.loading), loaded([Constant.a]), withPhase(.empty), withPhase(.error(Constant.message))]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .start), Decision(nextState: state))
        }
    }

    /// Retrying after an error clears everything and opens a new observation.
    func testRetryFromErrorBeginsObserving() {
        // Given
        var state = withPhase(.error(Constant.message))
        state.hasPrevious = false

        // When
        let decision = reduce(state, .retry)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loading)
        XCTAssertTrue(decision.nextState.hasPrevious)
        XCTAssertEqual(decision.effects, [.startObserving])
    }

    /// Retry only means something on the error screen.
    func testRetryIsIgnoredOutsideError() {
        // Given
        let states = [ChannelState(), withPhase(.loading), loaded([Constant.a]), withPhase(.empty)]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .retry), Decision(nextState: state))
        }
    }

    // MARK: - First page

    /// The first page replaces the list and records whether older messages remain.
    func testFirstPageLoadsTheList() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageLoaded(MessageFixtures.page([Constant.a, Constant.b], hasPrevious: true)))

        // Then
        XCTAssertEqual(decision.nextState.messages, [Constant.a, Constant.b])
        XCTAssertTrue(decision.nextState.hasPrevious)
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: false))
        XCTAssertTrue(decision.effects.isEmpty)
    }

    /// A channel with no messages shows the empty state.
    func testEmptyFirstPageShowsEmpty() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageLoaded(MessageFixtures.page([])))

        // Then
        XCTAssertEqual(decision.nextState.phase, .empty)
    }

    /// A failed first page replaces the screen with the error.
    func testFailedFirstPageShowsError() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageFailed(message: Constant.message))

        // Then
        XCTAssertEqual(decision.nextState.phase, .error(Constant.message))
        XCTAssertTrue(decision.nextState.messages.isEmpty)
    }

    /// A page nobody is waiting for is late and changes nothing.
    func testLatePageResultsAreIgnored() {
        // Given
        let states = [ChannelState(), loaded([Constant.a]), withPhase(.empty), withPhase(.error(Constant.message))]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .pageLoaded(MessageFixtures.page([Constant.b]))), Decision(nextState: state))
            XCTAssertEqual(reduce(state, .pageFailed(message: Constant.message)), Decision(nextState: state))
        }
    }

    // MARK: - Previous pages

    /// Scrolling to the top asks for one older page.
    func testLoadPreviousPageStartsLoading() {
        // Given
        let state = loaded([Constant.b], hasPrevious: true)

        // When
        let decision = reduce(state, .loadPreviousPage)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: true))
        XCTAssertEqual(decision.effects, [.loadPrevious])
    }

    /// No second request while one is in flight, none past the oldest page, none after a failure.
    func testLoadPreviousPageIsIgnoredWhenNotAllowed() {
        // Given
        var loading = loaded([Constant.b], hasPrevious: true)
        loading.phase = .loaded(isLoadingPrevious: true)
        var failed = loaded([Constant.b], hasPrevious: true)
        failed.loadPreviousError = Constant.message
        let states = [loading, loaded([Constant.b], hasPrevious: false), failed, withPhase(.loading)]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .loadPreviousPage), Decision(nextState: state))
        }
    }

    /// An older page replaces the list with the longer snapshot.
    func testPreviousPageExtendsTheList() {
        // Given
        var state = loaded([Constant.b], hasPrevious: true)
        state.phase = .loaded(isLoadingPrevious: true)

        // When
        let decision = reduce(state, .pageLoaded(MessageFixtures.page([Constant.a, Constant.b], hasPrevious: false)))

        // Then
        XCTAssertEqual(decision.nextState.messages, [Constant.a, Constant.b])
        XCTAssertFalse(decision.nextState.hasPrevious)
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: false))
    }

    /// A failed older page keeps the list and waits for an explicit retry.
    func testFailedPreviousPageKeepsTheList() {
        // Given
        var state = loaded([Constant.b], hasPrevious: true)
        state.phase = .loaded(isLoadingPrevious: true)

        // When
        let decision = reduce(state, .pageFailed(message: Constant.message))

        // Then
        XCTAssertEqual(decision.nextState.messages, [Constant.b])
        XCTAssertEqual(decision.nextState.loadPreviousError, Constant.message)
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: false))
    }

    /// Retrying a failed older page clears the error and loads it again.
    func testRetryPreviousPageAfterFailure() {
        // Given
        var state = loaded([Constant.b], hasPrevious: true)
        state.loadPreviousError = Constant.message

        // When
        let decision = reduce(state, .retryPreviousPage)

        // Then
        XCTAssertNil(decision.nextState.loadPreviousError)
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: true))
        XCTAssertEqual(decision.effects, [.loadPrevious])
    }

    /// Retrying an older page needs a failure to retry.
    func testRetryPreviousPageIsIgnoredWithoutFailure() {
        // Given
        let states = [loaded([Constant.b], hasPrevious: true), withPhase(.loading), withPhase(.error(Constant.message))]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .retryPreviousPage), Decision(nextState: state))
        }
    }

    // MARK: - Snapshots

    /// A live snapshot replaces the list once it is on screen.
    func testSnapshotReplacesLoadedList() {
        // Given
        let state = loaded([Constant.a])

        // When
        let decision = reduce(state, .messagesChanged([Constant.a, Constant.b]))

        // Then
        XCTAssertEqual(decision.nextState.messages, [Constant.a, Constant.b])
        XCTAssertTrue(decision.effects.isEmpty)
    }

    /// A message that changes in place comes back with the same id and new content.
    func testSnapshotUpdatesAMessageInPlace() {
        // Given
        let state = loaded([MessageFixtures.message("a", .text("Hel"))])
        let grown = MessageFixtures.message("a", .text("Hello"))

        // When
        let decision = reduce(state, .messagesChanged([grown]))

        // Then
        XCTAssertEqual(decision.nextState.messages, [grown])
    }

    /// The first live message turns the empty state into a list, and the reverse.
    func testSnapshotMovesBetweenEmptyAndLoaded() {
        // When
        let filled = reduce(withPhase(.empty), .messagesChanged([Constant.a]))
        let emptied = reduce(loaded([Constant.a]), .messagesChanged([]))

        // Then
        XCTAssertEqual(filled.nextState.phase, .loaded(isLoadingPrevious: false))
        XCTAssertEqual(emptied.nextState.phase, .empty)
    }

    /// A snapshot keeps an older-page request in flight.
    func testSnapshotKeepsPreviousPageLoading() {
        // Given
        var state = loaded([Constant.b], hasPrevious: true)
        state.phase = .loaded(isLoadingPrevious: true)

        // When
        let decision = reduce(state, .messagesChanged([Constant.b, MessageFixtures.message("c")]))

        // Then
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingPrevious: true))
    }

    /// Before the first page, and on the error screen, snapshots are ignored; an identical one
    /// changes nothing.
    func testSnapshotIsIgnoredWhenNotShowingAList() {
        // Given
        let states = [ChannelState(), withPhase(.loading), withPhase(.error(Constant.message))]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .messagesChanged([Constant.a])), Decision(nextState: state))
        }
        let unchanged = loaded([Constant.a])
        XCTAssertEqual(reduce(unchanged, .messagesChanged([Constant.a])), Decision(nextState: unchanged))
    }

    // MARK: - Losing the channel

    /// When the adapter ends the observation, the list gives way to the error.
    func testObservationEndedShowsError() {
        // Given
        var state = loaded([Constant.a], hasPrevious: true)
        state.loadPreviousError = Constant.message
        let states = [state, withPhase(.loading), withPhase(.empty)]

        // When / Then
        for state in states {
            let decision = reduce(state, .observationEnded(message: Constant.message))
            XCTAssertEqual(decision.nextState.phase, .error(Constant.message))
            XCTAssertTrue(decision.nextState.messages.isEmpty)
            XCTAssertNil(decision.nextState.loadPreviousError)
            XCTAssertTrue(decision.effects.isEmpty)
        }
    }

    /// An observation that ends before starting, or after the error is already up, changes nothing.
    func testObservationEndedIsIgnoredWhenIdleOrFailed() {
        // Given
        let states = [ChannelState(), withPhase(.error("Earlier"))]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .observationEnded(message: Constant.message)), Decision(nextState: state))
        }
    }

    // MARK: - Sending

    /// Sending only needs the repository: the message itself arrives in a later snapshot.
    func testSendTextRunsTheEffectWithoutChangingState() {
        // Given
        let states = [loaded([Constant.a]), withPhase(.empty), loading(previousOf: [Constant.a])]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .sendText(Constant.text)), Decision(nextState: state, effects: [.sendText(Constant.text, replyTo: nil)]))
        }
    }

    /// Before the list is on screen there is nothing to send into.
    func testSendTextIsIgnoredWhileTheListIsHidden() {
        // Given
        let states = Constant.hiddenPhases.map(withPhase)

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .sendText(Constant.text)), Decision(nextState: state))
        }
    }

    /// A channel the user cannot send to ignores sends even with the list on screen.
    func testSendTextIsIgnoredWhenTheUserCannotSend() {
        // Given
        let state = cannotSend(loaded([Constant.a]))

        // When
        let decision = reduce(state, .sendText(Constant.text))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state))
    }

    func testEmptyTextIsIgnored() {
        // Given
        let state = loaded([Constant.a])

        // When
        let decision = reduce(state, .sendText(""))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state))
    }

    func testResendFailedMessageRunsTheEffect() {
        // Given
        let state = loaded([Constant.a, Constant.failed])

        // When
        let decision = reduce(state, .resendMessage(id: Constant.failed.id))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state, effects: [.resendMessage(id: Constant.failed.id)]))
    }

    /// Only a failed message can be resent, so a repeated tap after it turned pending does nothing.
    func testResendIsIgnoredForMessagesThatAreNotFailed() {
        // Given
        let state = loaded([Constant.a, Constant.pending])
        let ids = [Constant.a.id, Constant.pending.id, Constant.unknownID]

        // When / Then
        for id in ids {
            XCTAssertEqual(reduce(state, .resendMessage(id: id)), Decision(nextState: state))
        }
    }

    /// Resending is a send, so it follows the same rule as sending text.
    func testResendIsIgnoredWhenTheUserCannotSend() {
        // Given
        let state = cannotSend(loaded([Constant.failed]))

        // When
        let decision = reduce(state, .resendMessage(id: Constant.failed.id))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state))
    }

    func testRemoveFailedMessageRunsTheEffect() {
        // Given
        let state = loaded([Constant.a, Constant.failed])

        // When
        let decision = reduce(state, .removeFailedMessage(id: Constant.failed.id))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state, effects: [.removeFailedMessage(id: Constant.failed.id)]))
    }

    /// A message that failed because the channel froze must stay removable.
    func testRemoveWorksWhenTheUserCannotSend() {
        // Given
        let state = cannotSend(loaded([Constant.failed]))

        // When
        let decision = reduce(state, .removeFailedMessage(id: Constant.failed.id))

        // Then
        XCTAssertEqual(decision.effects, [.removeFailedMessage(id: Constant.failed.id)])
    }

    func testRemoveIsIgnoredForMessagesThatAreNotFailed() {
        // Given
        let state = loaded([Constant.a, Constant.pending])
        let ids = [Constant.a.id, Constant.pending.id, Constant.unknownID]

        // When / Then
        for id in ids {
            XCTAssertEqual(reduce(state, .removeFailedMessage(id: id)), Decision(nextState: state))
        }
    }

    func testResendAndRemoveAreIgnoredWhileTheListIsHidden() {
        // Given
        let states = Constant.hiddenPhases.map { phase in
            var state = withPhase(phase)
            state.messages = [Constant.failed]
            return state
        }

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .resendMessage(id: Constant.failed.id)), Decision(nextState: state))
            XCTAssertEqual(reduce(state, .removeFailedMessage(id: Constant.failed.id)), Decision(nextState: state))
        }
    }

    // MARK: - Attachments

    /// Picked items are prepared first; nothing reaches the repository yet.
    func testSendAttachmentsStartsPreparation() {
        // Given
        let state = loaded([Constant.a])
        let sources = [AttachmentSourceFixtures.photo, AttachmentSourceFixtures.report]

        // When
        let decision = reduce(state, .sendAttachments(sources))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state, effects: [.prepareAttachments(sources, replyTo: nil)]))
    }

    /// An empty pick, a hidden list, and a channel without sending all ignore the pick.
    func testSendAttachmentsIsIgnoredWhenItCannotSend() {
        // Given
        let pick = [AttachmentSourceFixtures.photo]
        let cases: [(ChannelState, [AttachmentSource])] = [(loaded([Constant.a]), []), (cannotSend(loaded([Constant.a])), pick)]
            + Constant.hiddenPhases.map { (withPhase($0), pick) }

        // When / Then
        for (state, sources) in cases {
            XCTAssertEqual(reduce(state, .sendAttachments(sources)), Decision(nextState: state))
        }
    }

    /// Prepared files become one message.
    func testPreparedAttachmentsAreSent() {
        // Given
        let state = loaded([Constant.a])
        let prepared = [AttachmentSourceFixtures.preparedPhoto]

        // When
        let decision = reduce(state, .attachmentsPrepared(prepared, replyTo: nil))

        // Then
        XCTAssertEqual(decision, Decision(nextState: state, effects: [.sendAttachments(prepared, replyTo: nil)]))
    }

    /// Preparation that finishes after sending stopped being possible sends nothing and deletes the
    /// copies.
    func testLatePreparedAttachmentsAreDiscarded() {
        // Given
        let prepared = [AttachmentSourceFixtures.preparedPhoto]
        let states = [cannotSend(loaded([Constant.a]))] + Constant.hiddenPhases.map(withPhase)

        // When / Then
        for state in states {
            XCTAssertEqual(
                reduce(state, .attachmentsPrepared(prepared, replyTo: nil)),
                Decision(nextState: state, effects: [.discardAttachments(prepared)])
            )
        }
    }

    /// An empty preparation has nothing to send or delete.
    func testEmptyPreparedAttachmentsAreIgnored() {
        // Given
        let state = loaded([Constant.a])

        // When / Then
        XCTAssertEqual(reduce(state, .attachmentsPrepared([], replyTo: nil)), Decision(nextState: state))
    }

    func testPreparationFailureIsShownUntilDismissed() {
        // Given
        let state = loaded([Constant.a])

        // When
        let failed = reduce(state, .attachmentsFailed(message: Constant.message))
        let dismissed = reduce(failed.nextState, .dismissAttachmentError)

        // Then
        XCTAssertEqual(failed.nextState.attachmentError, Constant.message)
        XCTAssertTrue(failed.effects.isEmpty)
        XCTAssertNil(dismissed.nextState.attachmentError)
    }

    func testDismissWithoutAnErrorIsIgnored() {
        // Given
        let state = loaded([Constant.a])

        // When
        let decision = reduce(state, .dismissAttachmentError)

        // Then
        XCTAssertEqual(decision, Decision(nextState: state))
    }

    // MARK: - Replies

    /// A sent message in a channel with replies can be answered; the next start replaces it.
    func testStartReplySetsTheMessageAndAnotherReplacesIt() {
        // Given
        let state = replying(to: nil, in: [Constant.a, Constant.b])

        // When
        let first = reduce(state, .startReply(messageID: Constant.a.id))
        let second = reduce(first.nextState, .startReply(messageID: Constant.b.id))

        // Then
        XCTAssertEqual(first.nextState.replyingToID, Constant.a.id)
        XCTAssertEqual(first.effects, [])
        XCTAssertEqual(second.nextState.replyingToID, Constant.b.id)
    }

    /// Pending, failed, system, and unknown messages cannot be answered, nor anything while replies
    /// are off, sending is off, or the list is hidden.
    func testStartReplyIsIgnoredWhenTheMessageCannotBeAnswered() {
        // Given
        let messages = [Constant.a, Constant.pending, Constant.failed, Constant.system]
        var repliesOff = replying(to: nil, in: messages)
        repliesOff.canReply = false
        var hidden = replying(to: nil, in: messages)
        hidden.phase = .loading
        let cases: [(ChannelState, String)] = [
            (replying(to: nil, in: messages), Constant.pending.id),
            (replying(to: nil, in: messages), Constant.failed.id),
            (replying(to: nil, in: messages), Constant.system.id),
            (replying(to: nil, in: messages), Constant.unknownID),
            (repliesOff, Constant.a.id),
            (cannotSend(replying(to: nil, in: messages)), Constant.a.id),
            (hidden, Constant.a.id)
        ]

        // When / Then
        for (state, id) in cases {
            XCTAssertEqual(reduce(state, .startReply(messageID: id)), Decision(nextState: state))
        }
    }

    func testCancelReplyClearsItAndIsIgnoredWithoutOne() {
        // Given
        let replyingState = replying(to: Constant.a.id, in: [Constant.a])
        let idle = replying(to: nil, in: [Constant.a])

        // When
        let cancelled = reduce(replyingState, .cancelReply)

        // Then
        XCTAssertNil(cancelled.nextState.replyingToID)
        XCTAssertEqual(reduce(idle, .cancelReply), Decision(nextState: idle))
    }

    /// A text sent while replying answers that message and clears the reply in the same step.
    func testSendTextWhileReplyingSendsAReplyAndClearsIt() {
        // Given
        let state = replying(to: Constant.a.id, in: [Constant.a])

        // When
        let decision = reduce(state, .sendText(Constant.text))

        // Then
        XCTAssertNil(decision.nextState.replyingToID)
        XCTAssertEqual(decision.effects, [.sendText(Constant.text, replyTo: Constant.a.id)])
    }

    /// The reply is cleared the moment the user picks files, so a reply started while they are
    /// copied is not attached to them.
    func testSendAttachmentsWhileReplyingCarriesTheReplyAndClearsItAtOnce() {
        // Given
        let state = replying(to: Constant.a.id, in: [Constant.a])
        let sources = [AttachmentSourceFixtures.photo]

        // When
        let decision = reduce(state, .sendAttachments(sources))

        // Then
        XCTAssertNil(decision.nextState.replyingToID)
        XCTAssertEqual(decision.effects, [.prepareAttachments(sources, replyTo: Constant.a.id)])
    }

    func testPreparedAttachmentsAreSentAsTheReplyTheyWerePickedFor() {
        // Given
        let state = replying(to: nil, in: [Constant.a])
        let prepared = [AttachmentSourceFixtures.preparedPhoto]

        // When
        let decision = reduce(state, .attachmentsPrepared(prepared, replyTo: Constant.a.id))

        // Then
        XCTAssertEqual(decision.effects, [.sendAttachments(prepared, replyTo: Constant.a.id)])
    }

    /// The original was deleted, or replies turned off, while the files were copied: the files
    /// still go, as an ordinary message.
    func testLatePreparedAttachmentsGoAsAnOrdinaryMessageWhenTheOriginalCannotBeAnswered() {
        // Given
        let prepared = [AttachmentSourceFixtures.preparedPhoto]
        var repliesOff = replying(to: nil, in: [Constant.a])
        repliesOff.canReply = false
        let states = [replying(to: nil, in: [Constant.b]), repliesOff]

        // When / Then
        for state in states {
            XCTAssertEqual(
                reduce(state, .attachmentsPrepared(prepared, replyTo: Constant.a.id)).effects,
                [.sendAttachments(prepared, replyTo: nil)]
            )
        }
    }

    /// The reply is cleared when its message leaves the list or stops being a sent message.
    func testSnapshotWithoutTheOriginalClearsTheReply() {
        // Given
        let state = replying(to: Constant.a.id, in: [Constant.a, Constant.b])
        var failedOriginal = Constant.a
        failedOriginal.sendingStatus = .failed

        // When
        let removed = reduce(state, .messagesChanged([Constant.b]))
        let failed = reduce(state, .messagesChanged([failedOriginal, Constant.b]))
        let kept = reduce(state, .messagesChanged([Constant.a]))

        // Then
        XCTAssertNil(removed.nextState.replyingToID)
        XCTAssertNil(failed.nextState.replyingToID)
        XCTAssertEqual(kept.nextState.replyingToID, Constant.a.id)
    }

    /// Replies turning off clears the reply; sending turning off keeps it for when sending returns.
    func testChannelChangeClearsTheReplyOnlyWhenRepliesTurnOff() {
        // Given
        let state = replying(to: Constant.a.id, in: [Constant.a])
        let repliesOff = ChatChannel(id: "c", createdAt: MessageFixtures.start, canSendMessage: true, canReply: false)
        let sendingOff = ChatChannel(id: "c", createdAt: MessageFixtures.start, canSendMessage: false, canReply: true)

        // When
        let afterRepliesOff = reduce(state, .channelChanged(repliesOff))
        let afterSendingOff = reduce(state, .channelChanged(sendingOff))

        // Then
        XCTAssertNil(afterRepliesOff.nextState.replyingToID)
        XCTAssertFalse(afterRepliesOff.nextState.canReply)
        XCTAssertEqual(afterSendingOff.nextState.replyingToID, Constant.a.id)
        XCTAssertFalse(afterSendingOff.nextState.canSend)
    }

    /// A retry starts the list over, and an ended observation hides it; neither keeps the reply.
    func testRetryAndLosingTheChannelClearTheReply() {
        // Given
        var failedList = replying(to: Constant.a.id, in: [])
        failedList.phase = .error(Constant.message)
        let shown = replying(to: Constant.a.id, in: [Constant.a])

        // When
        let retried = reduce(failedList, .retry)
        let ended = reduce(shown, .observationEnded(message: Constant.message))

        // Then
        XCTAssertNil(retried.nextState.replyingToID)
        XCTAssertNil(ended.nextState.replyingToID)
    }

    // MARK: - Channel changes

    /// A newer channel value moves the permission in every phase, so the composer is right as soon
    /// as the list appears.
    func testChannelChangedUpdatesThePermissionInEveryPhase() {
        // Given
        let phases = Constant.hiddenPhases + [.loaded(isLoadingPrevious: false), .empty]
        let frozen = ChannelFixtures.channel { $0.canSendMessage = false }

        for phase in phases {
            // When
            let decision = reduce(withPhase(phase), .channelChanged(frozen))

            // Then
            XCTAssertFalse(decision.nextState.canSendMessage)
            XCTAssertEqual(decision.effects, [])
        }
    }

    /// A channel that can send again lets the composer send again.
    func testChannelChangedRestoresThePermission() {
        // Given
        let state = cannotSend(loaded([Constant.a]))

        // When
        let decision = reduce(state, .channelChanged(ChannelFixtures.channel()))

        // Then
        XCTAssertTrue(decision.nextState.canSend)
    }

    /// Other channel changes, such as a rename, leave the state alone.
    func testChannelChangedWithTheSamePermissionIsIgnored() {
        // Given
        let state = loaded([Constant.a])
        let renamed = ChannelFixtures.channel { $0.name = "Renamed" }

        // When / Then
        XCTAssertEqual(reduce(state, .channelChanged(renamed)), Decision(nextState: state))
    }

    // MARK: - canSend

    func testCanSendOnlyWithTheListOnScreenAndPermission() {
        // Given
        let allowed = [loaded([Constant.a]), withPhase(.empty), loading(previousOf: [Constant.a])]
        let denied = Constant.hiddenPhases.map(withPhase) + [cannotSend(loaded([Constant.a]))]

        // When / Then
        XCTAssertTrue(allowed.allSatisfy(\.canSend))
        XCTAssertFalse(denied.contains(where: \.canSend))
    }

    // MARK: - Helpers

    private func reduce(_ state: ChannelState, _ input: ChannelReducer.Input) -> Decision {
        ChannelReducer().reduce(state, input)
    }

    private func replying(to id: String?, in messages: [ChatMessage]) -> ChannelState {
        var state = loaded(messages)
        state.canReply = true
        state.replyingToID = id
        return state
    }

    private func withPhase(_ phase: ChannelState.Phase) -> ChannelState {
        var state = ChannelState()
        state.phase = phase
        return state
    }

    private func cannotSend(_ state: ChannelState) -> ChannelState {
        var state = state
        state.canSendMessage = false
        return state
    }

    private func loading(previousOf messages: [ChatMessage]) -> ChannelState {
        var state = loaded(messages, hasPrevious: true)
        state.phase = .loaded(isLoadingPrevious: true)
        return state
    }

    private func loaded(_ messages: [ChatMessage], hasPrevious: Bool = false) -> ChannelState {
        var state = ChannelState()
        state.phase = .loaded(isLoadingPrevious: false)
        state.messages = messages
        state.hasPrevious = hasPrevious
        return state
    }
}
