import Foundation
import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class ChannelStoreTests: XCTestCase {
    private enum Constant {
        static let currentUserID = "me"
        static let error = NSError(domain: "ChannelStoreTests", code: -1)
        static let a = MessageFixtures.message("a")
        static let b = MessageFixtures.message("b")
        static let c = MessageFixtures.message("c")
        static let text = "Hi there"
    }

    // MARK: - Observing

    /// Starting opens an observation and loads the latest page into rows.
    func testStartObservesAndLoadsLatestPage() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a, Constant.b], hasPrevious: true))])
        let store = makeStore(repository: spy)

        // When
        store.send(.start)
        await waitUntil { store.rows.count == 2 }

        // Then
        XCTAssertEqual(spy.startObservingCount, 1)
        XCTAssertEqual(spy.loadPreviousCount, 1)
        XCTAssertEqual(store.rows.map(\.id), ["a", "b"])
        XCTAssertEqual(store.rows.map(\.message), [Constant.a, Constant.b])
        XCTAssertEqual(store.state.phase, .loaded(isLoadingPrevious: false))
    }

    /// The spinner is on screen before the repository is even asked.
    func testStateIsStoredBeforeTheEffectRuns() {
        // Given
        let spy = ChannelRepositorySpy()
        let store = makeStore(repository: spy)

        // When
        store.send(.start)

        // Then
        XCTAssertEqual(store.state.phase, .loading)
        XCTAssertEqual(spy.startObservingCount, 0)
    }

    /// A failure from the backend reaches the state as display text.
    func testFailureBecomesDisplayText() async {
        // Given
        let spy = spy(with: [.failure(Constant.error)])
        let store = makeStore(repository: spy)

        // When
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // Then
        XCTAssertEqual(store.state.phase, .error(ErrorMessage.generic))
    }

    /// An error that describes itself for display keeps its own text.
    func testLocalizedErrorKeepsItsDescription() async {
        // Given
        let spy = spy(with: [.failure(DescribedError())])
        let store = makeStore(repository: spy)

        // When
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // Then
        XCTAssertEqual(store.state.phase, .error(DescribedError.description))
    }

    /// Live snapshots from the stream reach the rows.
    func testStreamSnapshotsUpdateRows() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let store = await startedStore(repository: spy)

        // When
        spy.emit([Constant.a, Constant.b])
        await waitUntil { store.rows.count == 2 }

        // Then
        XCTAssertEqual(store.rows.map(\.id), ["a", "b"])
    }

    /// Streamed text grows in place: the same row id carries the longer text.
    func testGrowingMessageUpdatesItsRow() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([MessageFixtures.message("a", .text("Hel"))]))])
        let store = await startedStore(repository: spy)

        // When
        spy.emit([MessageFixtures.message("a", .text("Hello"))])
        await waitUntil { store.rows.first?.content == .text("Hello") }

        // Then
        XCTAssertEqual(store.rows.map(\.id), ["a"])
        XCTAssertEqual(store.rows.first?.content, .text("Hello"))
    }

    func testCustomValueUpdatesFromTheStreamReachTheSameRow() async {
        // Given
        var original = Constant.a
        original.customContent = .init(CustomMessageFixtures.thinking)
        var updated = original
        updated.customContent = .init(CustomMessageFixtures.updatedThinking)
        let spy = spy(with: [.success(MessageFixtures.page([original]))])
        let store = await startedStore(repository: spy)
        let previousRows = store.rows

        // When
        spy.emit([updated])
        await waitUntil { store.rows.first?.message.customContent == updated.customContent }

        // Then
        XCTAssertEqual(store.rows.map(\.id), previousRows.map(\.id))
        XCTAssertEqual(store.rows.first?.content, previousRows.first?.content)
        XCTAssertEqual(store.rows.first?.message.customContent, updated.customContent)
        XCTAssertNotEqual(store.rows, previousRows)
    }

    func testAttributeUpdatesFromTheStreamReachTheSameRow() async {
        // Given
        var original = Constant.a
        original.customContent = .init(CustomMessageFixtures.thinking)
        original.attributes[CustomMessageFixtures.Moderation.self] = CustomMessageFixtures.unreported
        var updated = original
        updated.attributes[CustomMessageFixtures.Moderation.self] = CustomMessageFixtures.reported
        let spy = spy(with: [.success(MessageFixtures.page([original]))])
        let store = await startedStore(repository: spy)
        let previousRows = store.rows

        // When
        spy.emit([updated])
        await waitUntil { store.rows.first?.message.attributes == updated.attributes }

        // Then
        XCTAssertEqual(store.rows.map(\.id), previousRows.map(\.id))
        XCTAssertEqual(store.rows.first?.content, previousRows.first?.content)
        XCTAssertEqual(store.rows.first?.message.customContent, original.customContent)
        XCTAssertEqual(store.rows.first?.message.attributes[CustomMessageFixtures.Moderation.self], CustomMessageFixtures.reported)
        XCTAssertNotEqual(store.rows, previousRows)
    }

    func testAttachmentOnlyUpdatesFromTheStreamReachTheSameRow() async {
        // Given
        let original = ChatMessage(
            id: Constant.a.id, sender: Constant.a.sender, createdAt: MessageFixtures.start,
            attachments: [AttachmentFixtures.image]
        )
        var updated = original
        updated.attachments = [AttachmentFixtures.updatedImage]
        let spy = spy(with: [.success(MessageFixtures.page([original]))])
        let store = await startedStore(repository: spy)
        let previousRows = store.rows

        // When
        spy.emit([updated])
        await waitUntil { store.rows.first?.message.attachments == updated.attachments }

        // Then
        XCTAssertEqual(store.state.messages, [updated])
        XCTAssertEqual(store.rows.map(\.id), previousRows.map(\.id))
        XCTAssertEqual(store.rows.first?.content, .attachments(.init([AttachmentFixtures.updatedImage], text: "")))
        XCTAssertEqual(store.rows.first?.message, updated)
        XCTAssertNotEqual(store.rows, previousRows)
    }

    /// Date separators drop the year only within the current year, so rows built last year are
    /// not reused once a new year starts.
    func testNewYearRebuildsRowsThatWouldOtherwiseBeKept() async {
        // Given
        let clock = NowDouble(now: MessageFixtures.start)
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a, Constant.b]))])
        let store = ChannelStore(
            repository: spy,
            currentUserID: Constant.currentUserID,
            canSendMessage: true,
            now: { clock.now }
        )
        store.send(.start)
        await waitUntil { store.rows.count == 2 }
        let lastYearSeparator = store.rows[0].dateSeparator

        // When
        clock.now = MessageFixtures.start.addingTimeInterval(365 * 24 * 3_600)
        spy.emit([Constant.a, Constant.b, MessageFixtures.message("c", from: "u2")])
        await waitUntil { store.rows.count == 3 }

        // Then
        XCTAssertNotNil(store.rows[0].dateSeparator)
        XCTAssertNotEqual(store.rows[0].dateSeparator, lastYearSeparator)
    }

    /// Date separators name today, so rows built yesterday are not reused after midnight.
    func testNewDayRebuildsRowsThatWouldOtherwiseBeKept() async {
        // Given
        let clock = NowDouble(now: MessageFixtures.start)
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a, Constant.b]))])
        let store = ChannelStore(
            repository: spy,
            currentUserID: Constant.currentUserID,
            canSendMessage: true,
            now: { clock.now }
        )
        store.send(.start)
        await waitUntil { store.rows.count == 2 }
        let todaySeparator = store.rows[0].dateSeparator

        // When
        clock.now = MessageFixtures.start.addingTimeInterval(24 * 3_600)
        spy.emit([Constant.a, Constant.b, MessageFixtures.message("c", from: "u2")])
        await waitUntil { store.rows.count == 3 }

        // Then
        XCTAssertNotNil(store.rows[0].dateSeparator)
        XCTAssertNotEqual(store.rows[0].dateSeparator, todaySeparator)
    }

    // MARK: - Previous pages

    /// Scrolling to the top loads one older page.
    func testLoadPreviousPageExtendsRows() async {
        // Given
        let spy = spy(with: [
            .success(MessageFixtures.page([Constant.b, Constant.c], hasPrevious: true)),
            .success(MessageFixtures.page([Constant.a, Constant.b, Constant.c]))
        ])
        let store = await startedStore(repository: spy)

        // When
        store.send(.loadPreviousPage)
        await waitUntil { store.rows.count == 3 }

        // Then
        XCTAssertEqual(spy.loadPreviousCount, 2)
        XCTAssertEqual(store.rows.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(store.rows.map(\.message), [Constant.a, Constant.b, Constant.c])
        XCTAssertFalse(store.state.hasPrevious)
    }

    // MARK: - Replacing and losing the observation

    /// Retrying replaces the observation, and ending the replaced one is not mistaken for losing
    /// the channel.
    func testRetryReplacesTheObservation() async {
        // Given
        let spy = spy(with: [.failure(Constant.error), .success(MessageFixtures.page([Constant.a]))])
        let store = makeStore(repository: spy)
        store.send(.start)
        await waitUntil { store.state.phase == .error(ErrorMessage.generic) }

        // When
        store.send(.retry)
        await waitUntil { store.rows.count == 1 && spy.terminatedStreamCount == 1 }

        // Then
        XCTAssertEqual(spy.startObservingCount, 2)
        XCTAssertEqual(store.state.phase, .loaded(isLoadingPrevious: false))
    }

    /// When the adapter ends the stream, the screen shows that the channel is gone.
    func testEndedStreamShowsChannelUnavailable() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let store = await startedStore(repository: spy)

        // When
        spy.finishStream()
        await waitUntil { store.state.phase != .loaded(isLoadingPrevious: false) }

        // Then
        XCTAssertEqual(store.state.phase, .error(ChannelStore.channelUnavailableMessage))
        XCTAssertTrue(store.rows.isEmpty)
    }

    /// Retrying a lost channel keeps saying it is gone instead of asking to try again.
    func testChannelNotFoundShowsChannelUnavailable() async {
        // Given
        let spy = spy(with: [.failure(ChannelRepositoryError.channelNotFound)])
        let store = makeStore(repository: spy)

        // When
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // Then
        XCTAssertEqual(store.state.phase, .error(ChannelStore.channelUnavailableMessage))
    }

    /// An older page still in flight when the channel is lost cannot bring the list back.
    func testPageInFlightIsDroppedWhenTheChannelIsLost() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.b], hasPrevious: true))])
        let store = await startedStore(repository: spy)
        spy.holdsLoadPrevious = true
        store.send(.loadPreviousPage)
        await waitUntil { spy.loadPreviousCount == 2 }

        // When
        spy.finishStream()
        await waitUntil { store.state.phase == .error(ChannelStore.channelUnavailableMessage) }
        spy.resumeLoadPrevious(with: .success(MessageFixtures.page([Constant.a, Constant.b])))
        for _ in 0..<10 {
            await Task.yield()
        }

        // Then
        XCTAssertEqual(store.state.phase, .error(ChannelStore.channelUnavailableMessage))
        XCTAssertTrue(store.rows.isEmpty)
    }

    // MARK: - Sending

    /// Each send effect reaches the repository right away; there is no completion to wait for.
    func testSendEffectsCallTheRepository() async {
        // Given
        let failed = MessageFixtures.message("failed", from: Constant.currentUserID, sendingStatus: .failed)
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a, failed]))])
        let store = await startedStore(repository: spy)

        // When
        store.send(.sendText(Constant.text))
        store.send(.resendMessage(id: failed.id))
        store.send(.removeFailedMessage(id: failed.id))

        // Then
        XCTAssertEqual(spy.sentTexts, [Constant.text])
        XCTAssertEqual(spy.resentMessageIDs, [failed.id])
        XCTAssertEqual(spy.removedMessageIDs, [failed.id])
    }

    /// A reply started from the list reaches the repository with the original's id, for text and
    /// for attachments picked while replying, and the next send is an ordinary message again.
    func testSendsWhileReplyingCarryTheOriginalToTheRepository() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.result = .success([AttachmentSourceFixtures.preparedPhoto])
        let store = makeStore(repository: spy, canReply: true, preparation: preparation)
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // When
        store.send(.startReply(messageID: Constant.a.id))
        store.send(.sendText(Constant.text))
        store.send(.sendText(Constant.text))
        store.send(.startReply(messageID: Constant.a.id))
        store.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        await waitUntil { spy.sentAttachments.count == 1 }

        // Then
        XCTAssertEqual(spy.sentReplyTos, [Constant.a.id, nil, Constant.a.id])
        XCTAssertNil(store.state.replyingToID)
    }

    /// The channel's permission reaches the state, so a channel that cannot send never calls the
    /// repository.
    func testStoreWithoutPermissionDoesNotSend() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let store = makeStore(repository: spy, canSendMessage: false)
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // When
        store.send(.sendText(Constant.text))

        // Then
        XCTAssertFalse(store.state.canSend)
        XCTAssertTrue(spy.sentTexts.isEmpty)
    }

    /// A newer channel value reaches the state, so sending follows it without a new Store.
    func testChannelChangeTurnsSendingOnAndOff() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let store = makeStore(repository: spy, canSendMessage: false)
        store.send(.start)
        await waitUntil { store.state.phase != .loading }

        // When
        store.send(.channelChanged(ChannelFixtures.channel()))
        store.send(.sendText(Constant.text))
        store.send(.channelChanged(ChannelFixtures.channel { $0.canSendMessage = false }))
        store.send(.sendText(Constant.text))

        // Then
        XCTAssertFalse(store.state.canSend)
        XCTAssertEqual(spy.sentTexts, [Constant.text])
    }

    /// A pending message that comes back sent keeps its row; only the row's message changes.
    func testSentSnapshotUpdatesThePendingRowInPlace() async {
        // Given
        let pending = MessageFixtures.message("mine", from: Constant.currentUserID, sendingStatus: .pending)
        var sent = pending
        sent.sendingStatus = nil
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a, pending]))])
        let store = await startedStore(repository: spy)

        // When
        spy.emit([Constant.a, sent])
        await waitUntil { store.rows.last?.message.sendingStatus == nil }

        // Then
        XCTAssertEqual(store.rows.map(\.id), [Constant.a.id, pending.id])
    }

    // MARK: - Attachments

    /// Picked items are prepared, then sent as one message.
    func testPreparedAttachmentsReachTheRepository() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.result = .success([AttachmentSourceFixtures.preparedPhoto])
        let store = await startedStore(repository: spy, preparation: preparation)

        // When
        store.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        await waitUntil { !spy.sentAttachments.isEmpty }

        // Then
        XCTAssertEqual(preparation.preparedSources, [[AttachmentSourceFixtures.photo]])
        XCTAssertEqual(spy.sentAttachments, [[AttachmentSourceFixtures.preparedPhoto]])
    }

    /// A failed preparation sends nothing and shows the general message.
    func testPreparationFailureSetsTheError() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.result = .failure(Constant.error)
        let store = await startedStore(repository: spy, preparation: preparation)

        // When
        store.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        await waitUntil { store.state.attachmentError != nil }

        // Then
        XCTAssertEqual(store.state.attachmentError, ChannelStore.attachmentFailureMessage)
        XCTAssertTrue(spy.sentAttachments.isEmpty)
    }

    /// Picking the very same items again replaces the first run, whose late result is dropped.
    func testSamePickReplacesTheEarlierPreparation() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.holds = true
        let store = await startedStore(repository: spy, preparation: preparation)
        let pick = [AttachmentSourceFixtures.photo]
        store.send(.sendAttachments(pick))
        await waitUntil { preparation.preparedSources.count == 1 }
        store.send(.sendAttachments(pick))
        await waitUntil { preparation.preparedSources.count == 2 }

        // When
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        await waitUntil { !spy.sentAttachments.isEmpty }

        // Then
        XCTAssertEqual(spy.sentAttachments.count, 1)
    }

    /// Different picks prepare side by side and both send.
    func testDifferentPicksPrepareSideBySide() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.holds = true
        let store = await startedStore(repository: spy, preparation: preparation)
        store.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        store.send(.sendAttachments([AttachmentSourceFixtures.report]))
        await waitUntil { preparation.preparedSources.count == 2 }

        // When
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        await waitUntil { spy.sentAttachments.count == 2 }

        // Then
        XCTAssertEqual(spy.sentAttachments.count, 2)
    }

    /// Copies that arrive after sending turned off are deleted instead of sent.
    func testPreparedAttachmentsAreDiscardedWhenSendingTurnedOff() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.holds = true
        let store = await startedStore(repository: spy, preparation: preparation)
        store.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        await waitUntil { preparation.preparedSources.count == 1 }
        store.send(.channelChanged(ChannelFixtures.channel { $0.canSendMessage = false }))

        // When
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        await waitUntil { !preparation.discarded.isEmpty }

        // Then
        XCTAssertEqual(preparation.discarded, [[AttachmentSourceFixtures.preparedPhoto]])
        XCTAssertTrue(spy.sentAttachments.isEmpty)
    }

    /// A run replaced by the same pick deletes its copies; the newer run sends.
    func testReplacedPreparationDiscardsItsCopies() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.holds = true
        let store = await startedStore(repository: spy, preparation: preparation)
        let pick = [AttachmentSourceFixtures.photo]
        store.send(.sendAttachments(pick))
        await waitUntil { preparation.preparedSources.count == 1 }
        store.send(.sendAttachments(pick))
        await waitUntil { preparation.preparedSources.count == 2 }

        // When
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedReport]))
        await waitUntil { !spy.sentAttachments.isEmpty && !preparation.discarded.isEmpty }

        // Then
        XCTAssertEqual(preparation.discarded, [[AttachmentSourceFixtures.preparedPhoto]])
        XCTAssertEqual(spy.sentAttachments, [[AttachmentSourceFixtures.preparedReport]])
    }

    /// Copies that finish after the Store is gone are deleted.
    func testPreparationOutlivingTheStoreDiscardsItsCopies() async {
        // Given
        let spy = spy(with: [.success(MessageFixtures.page([Constant.a]))])
        let preparation = AttachmentPreparationDouble()
        preparation.holds = true
        var store: ChannelStore? = await startedStore(repository: spy, preparation: preparation)
        store?.send(.sendAttachments([AttachmentSourceFixtures.photo]))
        await waitUntil { preparation.preparedSources.count == 1 }
        store = nil

        // When
        preparation.resume(with: .success([AttachmentSourceFixtures.preparedPhoto]))
        await waitUntil { !preparation.discarded.isEmpty }

        // Then
        XCTAssertEqual(preparation.discarded, [[AttachmentSourceFixtures.preparedPhoto]])
        XCTAssertTrue(spy.sentAttachments.isEmpty)
    }

    // MARK: - Helpers

    private func makeStore(
        repository: ChannelRepositorySpy,
        canSendMessage: Bool = true,
        canReply: Bool = false,
        preparation: AttachmentPreparationDouble = AttachmentPreparationDouble()
    ) -> ChannelStore {
        ChannelStore(
            repository: repository,
            currentUserID: Constant.currentUserID,
            canSendMessage: canSendMessage,
            canReply: canReply,
            now: { MessageFixtures.start },
            prepareAttachments: { try await preparation.prepare($0) },
            discardAttachments: { preparation.discard($0) }
        )
    }

    private func startedStore(
        repository: ChannelRepositorySpy,
        preparation: AttachmentPreparationDouble = AttachmentPreparationDouble()
    ) async -> ChannelStore {
        let store = makeStore(repository: repository, preparation: preparation)
        store.send(.start)
        await waitUntil { store.state.phase != .loading }
        return store
    }

    private func spy(with results: [Result<MessagePage, any Error>]) -> ChannelRepositorySpy {
        let spy = ChannelRepositorySpy()
        spy.loadPreviousResults = results
        return spy
    }
}

private final class NowDouble {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct DescribedError: LocalizedError {
    static let description = "The channel is frozen."

    var errorDescription: String? { Self.description }
}
