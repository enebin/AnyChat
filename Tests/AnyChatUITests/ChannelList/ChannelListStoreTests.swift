import Foundation
import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class ChannelListStoreTests: XCTestCase {
    private enum Constant {
        static let currentUserID = "me"
        static let now = Date(timeIntervalSince1970: 1_730_819_040)
        static let error = NSError(domain: "ChannelListStoreTests", code: -1)
    }

    // MARK: - Observing

    /// Starting opens an observation and loads the first page into rows.
    func testStartObservesAndLoadsFirstPage() async {
        // Given
        let spy = spy(with: [.page([channel("a"), channel("b")], hasNext: true)])
        let store = makeStore(repository: spy)

        // When
        store.send(.start)
        await waitUntil { store.rows.count == 2 }

        // Then
        XCTAssertEqual(spy.startObservingCount, 1)
        XCTAssertEqual(spy.loadMoreCount, 1)
        XCTAssertEqual(store.rows.map(\.id), ["a", "b"])
        XCTAssertEqual(store.state.phase, .loaded(isLoadingNext: false))
    }

    /// The spinner is on screen before the repository is even asked.
    func testStateIsStoredBeforeTheEffectRuns() {
        // Given
        let spy = ChannelListRepositorySpy()
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
        XCTAssertEqual(store.state.phase, .error(ChannelListStore.genericErrorMessage))
    }

    /// An error that describes itself for display reaches the state with its own text.
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

    /// Retrying after a failure opens a brand new observation.
    func testRetryOpensANewObservation() async {
        // Given
        let spy = spy(with: [.failure(Constant.error)])
        let store = makeStore(repository: spy)
        store.send(.start)
        await waitUntil { store.state.phase != .loading }
        spy.loadMoreResults = [.page([channel("a")])]

        // When
        store.send(.retry)
        await waitUntil { store.state.phase == .loaded(isLoadingNext: false) }

        // Then
        XCTAssertEqual(spy.startObservingCount, 2)
        XCTAssertEqual(store.rows.map(\.id), ["a"])
    }

    /// Each snapshot on the stream replaces the rows.
    func testSnapshotsOnTheStreamReplaceRows() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))

        // When
        loaded.spy.emit([channel("a"), channel("c")])
        await waitUntil { loaded.store.rows.count == 2 }

        // Then
        XCTAssertEqual(loaded.store.rows.map(\.id), ["a", "c"])
    }

    /// Releasing the store cancels observation, which releases the backend's resources.
    func testReleasingStoreStopsObserving() async {
        // Given
        let spy = spy(with: [.page([channel("a")])])
        var store: ChannelListStore? = makeStore(repository: spy)
        store?.send(.start)
        await waitUntil { spy.loadMoreCount == 1 }

        // When
        store = nil

        // Then
        await waitUntil { spy.stopObservingCount > 0 }
        XCTAssertGreaterThan(spy.stopObservingCount, 0)
    }

    // MARK: - Pagination

    /// Asking for the next page loads it and applies the new snapshot.
    func testLoadNextPageLoadsAndAppliesThePage() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")], hasNext: true)]))
        loaded.spy.loadMoreResults = [.page([channel("a"), channel("b")])]

        // When
        loaded.store.send(.loadNextPage)
        await waitUntil { loaded.store.rows.count == 2 }

        // Then
        XCTAssertEqual(loaded.spy.loadMoreCount, 2)
        XCTAssertEqual(loaded.store.state.paginationStatus, .done)
    }

    /// A refresh replaces an in-flight next page, and that page's late result is dropped.
    func testRefreshDropsAnInFlightNextPage() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")], hasNext: true)]))
        loaded.spy.holdsLoadMore = true
        loaded.store.send(.loadNextPage)
        await waitUntil { loaded.spy.loadMoreCount == 2 }

        // When
        let refresh = Task { await loaded.store.refresh() }
        await waitUntil { loaded.spy.loadMoreCount == 3 }
        loaded.spy.resumeLoadMore(with: .page([channel("stale")]))
        loaded.spy.resumeLoadMore(with: .page([channel("b")]))
        await refresh.value

        // Then
        XCTAssertEqual(loaded.store.rows.map(\.id), ["b"])
        XCTAssertNil(loaded.store.state.loadMoreError)
    }

    // MARK: - Refresh

    /// `refresh()` keeps the rows while waiting and returns only once the new page arrives.
    func testRefreshWaitsForTheNewFirstPage() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))
        loaded.spy.holdsLoadMore = true

        // When
        let refresh = Task { await loaded.store.refresh() }
        await waitUntil { loaded.spy.startObservingCount == 2 && loaded.spy.loadMoreCount == 2 }

        // Then: the old rows are still visible and there is no full-screen spinner.
        XCTAssertTrue(loaded.store.state.isRefreshing)
        XCTAssertFalse(loaded.store.state.isLoading)
        XCTAssertEqual(loaded.store.rows.map(\.id), ["a"])

        // Then: the new page replaces them, and only then does `refresh()` return.
        loaded.spy.resumeLoadMore(with: .page([channel("b")]))
        await refresh.value
        XCTAssertFalse(loaded.store.state.isRefreshing)
        XCTAssertEqual(loaded.store.rows.map(\.id), ["b"])
    }

    /// A failed refresh returns, keeps the rows, and hands the error to the host.
    func testRefreshFailureReturnsAndEmitsError() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))
        loaded.spy.loadMoreResults = [.failure(Constant.error)]

        // When
        await loaded.store.refresh()

        // Then
        XCTAssertEqual(loaded.store.rows.map(\.id), ["a"])
        XCTAssertEqual(
            loaded.store.outboundEvent?.event,
            .failed(message: ChannelListStore.genericErrorMessage)
        )
    }

    /// A refresh the reducer ignores does not leave the caller suspended.
    func testIgnoredRefreshReturnsImmediately() async {
        // Given
        let spy = ChannelListRepositorySpy()
        spy.holdsLoadMore = true
        let store = makeStore(repository: spy)
        store.send(.start)

        // When
        await store.refresh()

        // Then
        XCTAssertTrue(store.state.isLoading)
        XCTAssertFalse(store.state.isRefreshing)

        spy.resumeLoadMore(with: .page([]))
    }

    // MARK: - Channel actions

    /// Leaving marks the row busy, calls the repository by id, then hands the channel to the host.
    func testLeaveRunsAndEmitsLeftChannel() async {
        // Given
        let target = channel("a")
        let loaded = await makeLoadedStore(spy: spy(with: [.page([target])]))

        // When
        loaded.store.send(.leave(channelID: "a"))

        // Then
        XCTAssertEqual(loaded.store.rows.first?.isActionPending, true)
        await waitUntil { loaded.store.outboundEvent != nil }
        XCTAssertEqual(loaded.spy.leftChannelIDs, ["a"])
        XCTAssertEqual(loaded.store.rows.first?.isActionPending, false)
        XCTAssertEqual(loaded.store.outboundEvent?.event, .leftChannel(target))
    }

    /// A failed leave reaches the host as display text.
    func testLeaveFailureEmitsDisplayText() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))
        loaded.spy.leaveResult = .failure(Constant.error)

        // When
        loaded.store.send(.leave(channelID: "a"))
        await waitUntil { loaded.store.outboundEvent != nil }

        // Then
        XCTAssertEqual(loaded.store.outboundEvent?.event, .failed(message: ChannelListStore.genericErrorMessage))
    }

    /// Toggling notifications sends the new level by id.
    func testToggleNotificationsCallsRepository() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))

        // When
        loaded.store.send(.toggleNotifications(channelID: "a"))
        await waitUntil { loaded.store.outboundEvent != nil }

        // Then
        XCTAssertEqual(loaded.spy.notificationLevelChanges.map(\.channelID), ["a"])
        XCTAssertEqual(loaded.spy.notificationLevelChanges.map(\.level), [.off])
    }

    /// Two emissions of equal events still read as two events.
    func testEqualEventsGetDistinctIDs() async {
        // Given
        let loaded = await makeLoadedStore(spy: spy(with: [.page([channel("a")])]))
        loaded.spy.leaveResult = .failure(Constant.error)
        loaded.store.send(.leave(channelID: "a"))
        await waitUntil { loaded.store.outboundEvent != nil }
        let first = loaded.store.outboundEvent

        // When
        loaded.store.send(.leave(channelID: "a"))
        await waitUntil { loaded.store.outboundEvent != first }

        // Then
        XCTAssertEqual(loaded.store.outboundEvent?.event, first?.event)
        XCTAssertNotEqual(loaded.store.outboundEvent?.id, first?.id)
    }

    // MARK: - Helpers

    private struct LoadedStore {
        let store: ChannelListStore
        let spy: ChannelListRepositorySpy
    }

    private func makeStore(repository: some ChannelListRepository) -> ChannelListStore {
        ChannelListStore(
            repository: repository,
            currentUserID: Constant.currentUserID,
            options: ChannelListOptions(),
            now: { Constant.now }
        )
    }

    private func spy(with results: [Result<ChannelListPage, any Error>]) -> ChannelListRepositorySpy {
        let spy = ChannelListRepositorySpy()
        spy.loadMoreResults = results
        return spy
    }

    private func makeLoadedStore(spy: ChannelListRepositorySpy) async -> LoadedStore {
        let store = makeStore(repository: spy)
        store.send(.start)
        await waitUntil { store.state.phase != .idle && store.state.phase != .loading }
        return LoadedStore(store: store, spy: spy)
    }

    private func channel(_ id: String) -> ChatChannel {
        ChannelFixtures.channel(id: id) {
            $0.name = id
            $0.notificationLevel = .all
            $0.canLeave = true
        }
    }
}

private struct DescribedError: LocalizedError {
    static let description = "The backend is offline."

    var errorDescription: String? { Self.description }
}

private extension Result where Success == ChannelListPage, Failure == any Error {
    static func page(_ channels: [ChatChannel], hasNext: Bool = false) -> Self {
        .success(ChannelListPage(channels: channels, hasNext: hasNext))
    }
}
