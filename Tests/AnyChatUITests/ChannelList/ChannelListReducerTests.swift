import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ChannelListReducerTests: XCTestCase {
    private typealias Decision = ChannelListReducer.Decision

    private enum Constant {
        static let message = "Something broke"
        static let a = channel("a")
        static let b = channel("b")
    }

    // MARK: - First load

    /// Nothing happens until the view asks for it.
    func testInitialStateIsIdle() {
        // Given / When
        let state = ChannelListState()

        // Then
        XCTAssertEqual(state.phase, .idle)
        XCTAssertTrue(state.channels.isEmpty)
        XCTAssertTrue(state.hasNext)
    }

    /// The first start shows a spinner and opens an observation.
    func testStartFromIdleBeginsObserving() {
        // Given
        let state = ChannelListState()

        // When
        let decision = reduce(state, .start)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loading)
        XCTAssertEqual(decision.effects, [.startObserving])
    }

    /// Coming back to a screen that already loaded must not reload it.
    func testStartIsIgnoredOnceStarted() {
        // Given
        let states = [
            loaded([Constant.a]),
            withPhase(.loading),
            withPhase(.empty),
            withPhase(.error(Constant.message))
        ]

        // When / Then
        for state in states {
            XCTAssertEqual(reduce(state, .start), Decision(nextState: state))
        }
    }

    /// The first page replaces the list and records whether more pages exist.
    func testFirstPageLoadsTheList() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageLoaded(ChannelListPage(channels: [Constant.a, Constant.b], hasNext: true)))

        // Then
        XCTAssertEqual(decision.nextState.channels, [Constant.a, Constant.b])
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: false))
        XCTAssertTrue(decision.nextState.hasNext)
        XCTAssertEqual(decision.effects, [])
    }

    /// An account with no channels shows the empty state, not an empty list.
    func testEmptyFirstPageSetsEmptyPhase() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageLoaded(ChannelListPage(channels: [], hasNext: false)))

        // Then
        XCTAssertEqual(decision.nextState.phase, .empty)
    }

    /// A failed first page takes over the whole screen.
    func testFirstPageFailureSetsErrorPhase() {
        // Given
        let state = withPhase(.loading)

        // When
        let decision = reduce(state, .pageFailed(message: Constant.message))

        // Then
        XCTAssertEqual(decision.nextState.phase, .error(Constant.message))
        XCTAssertNil(decision.nextState.loadMoreError)
        XCTAssertEqual(decision.effects, [])
    }

    /// Retrying after a failure starts a brand new observation.
    func testRetryAfterFailureBeginsObserving() {
        // Given
        let state = withPhase(.error(Constant.message))

        // When
        let decision = reduce(state, .retry)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loading)
        XCTAssertEqual(decision.effects, [.startObserving])
    }

    /// Retry only means something after the first page failed.
    func testRetryIsIgnoredWithoutAFailure() {
        // Given
        let state = loaded([Constant.a])

        // When / Then
        XCTAssertEqual(reduce(state, .retry), Decision(nextState: state))
    }

    // MARK: - Pagination

    /// Scrolling near the end asks for the next page and shows the footer spinner.
    func testLoadNextPageRequestsAPage() {
        // Given
        let state = loaded([Constant.a], hasNext: true)

        // When
        let decision = reduce(state, .loadNextPage)

        // Then
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: true))
        XCTAssertEqual(decision.nextState.paginationStatus, .loading)
        XCTAssertEqual(decision.effects, [.loadMore])
    }

    /// A later page replaces the list with the new whole-list snapshot.
    func testNextPageAppliesNewSnapshot() {
        // Given
        let state = reduce(loaded([Constant.a], hasNext: true), .loadNextPage).nextState

        // When
        let decision = reduce(state, .pageLoaded(ChannelListPage(channels: [Constant.a, Constant.b], hasNext: false)))

        // Then
        XCTAssertEqual(decision.nextState.channels, [Constant.a, Constant.b])
        XCTAssertFalse(decision.nextState.hasNext)
        XCTAssertEqual(decision.nextState.paginationStatus, .done)
    }

    /// The last page stops the list from asking for more.
    func testLoadNextPageIsIgnoredWithoutANextPage() {
        // Given
        let state = loaded([Constant.a], hasNext: false)

        // When / Then
        XCTAssertEqual(reduce(state, .loadNextPage), Decision(nextState: state))
    }

    /// Scrolling fast must not fire overlapping page requests.
    func testLoadNextPageIsIgnoredWhileAPageIsLoading() {
        // Given
        let state = reduce(loaded([Constant.a], hasNext: true), .loadNextPage).nextState

        // When / Then
        XCTAssertEqual(reduce(state, .loadNextPage), Decision(nextState: state))
    }

    /// A failed later page keeps the list and offers a retry in the footer.
    func testNextPageFailureKeepsListAndOffersRetry() {
        // Given
        let state = reduce(loaded([Constant.a], hasNext: true), .loadNextPage).nextState

        // When
        let decision = reduce(state, .pageFailed(message: Constant.message))

        // Then
        XCTAssertEqual(decision.nextState.channels, [Constant.a])
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: false))
        XCTAssertEqual(decision.nextState.loadMoreError, Constant.message)
        XCTAssertEqual(decision.nextState.paginationStatus, .retry)
        XCTAssertFalse(decision.nextState.canLoadNextPage)
    }

    /// Scrolling must not retry a failed page on its own.
    func testLoadNextPageIsIgnoredAfterAFailure() {
        // Given
        let state = failedNextPage()

        // When / Then
        XCTAssertEqual(reduce(state, .loadNextPage), Decision(nextState: state))
    }

    /// Tapping retry in the footer asks for the page again and clears the error.
    func testRetryNextPageRequestsThePageAgain() {
        // Given
        let state = failedNextPage()

        // When
        let decision = reduce(state, .retryNextPage)

        // Then
        XCTAssertNil(decision.nextState.loadMoreError)
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: true))
        XCTAssertEqual(decision.effects, [.loadMore])
    }

    /// The footer retry only means something after a later page failed.
    func testRetryNextPageIsIgnoredWithoutAFailure() {
        // Given
        let state = loaded([Constant.a], hasNext: true)

        // When / Then
        XCTAssertEqual(reduce(state, .retryNextPage), Decision(nextState: state))
    }

    // MARK: - Refresh

    /// Pull-to-refresh keeps the list on screen while a new observation opens.
    func testRefreshKeepsListAndBeginsObserving() {
        // Given
        let state = failedNextPage()

        // When
        let decision = reduce(state, .refresh)

        // Then
        XCTAssertTrue(decision.nextState.isRefreshing)
        XCTAssertFalse(decision.nextState.isLoading)
        XCTAssertNil(decision.nextState.loadMoreError)
        XCTAssertEqual(decision.nextState.channels, [Constant.a])
        XCTAssertEqual(decision.effects, [.startObserving])
    }

    /// The new first page replaces the old list and ends the refresh.
    func testRefreshEndsWithTheNewFirstPage() {
        // Given
        let state = reduce(loaded([Constant.a]), .refresh).nextState

        // When
        let decision = reduce(state, .pageLoaded(ChannelListPage(channels: [Constant.b], hasNext: false)))

        // Then
        XCTAssertFalse(decision.nextState.isRefreshing)
        XCTAssertEqual(decision.nextState.channels, [Constant.b])
    }

    /// A failed refresh keeps the list and reports the error to the host.
    func testRefreshFailureKeepsListAndNotifies() {
        // Given
        let state = reduce(loaded([Constant.a]), .refresh).nextState

        // When
        let decision = reduce(state, .pageFailed(message: Constant.message))

        // Then
        XCTAssertFalse(decision.nextState.isRefreshing)
        XCTAssertEqual(decision.nextState.channels, [Constant.a])
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: false))
        XCTAssertEqual(decision.effects, [.notify(.failed(message: Constant.message))])
    }

    /// A second pull while refreshing, or a pull during the first load, does nothing.
    func testRefreshIsIgnoredWhileRefreshingOrLoading() {
        // Given
        let refreshing = reduce(loaded([Constant.a]), .refresh).nextState
        let loading = withPhase(.loading)

        // When / Then
        XCTAssertEqual(reduce(refreshing, .refresh), Decision(nextState: refreshing))
        XCTAssertEqual(reduce(loading, .refresh), Decision(nextState: loading))
    }

    /// Retrying the first load abandons a refresh rather than leaving it hanging.
    func testBeginningObservationEndsARefresh() {
        // Given
        var state = withPhase(.error(Constant.message))
        state.isRefreshing = true

        // When
        let decision = reduce(state, .retry)

        // Then
        XCTAssertFalse(decision.nextState.isRefreshing)
    }

    // MARK: - Live updates

    /// A snapshot replaces the list.
    func testSnapshotReplacesChannels() {
        // Given
        let state = loaded([Constant.a])

        // When
        let decision = reduce(state, .channelsChanged([Constant.a, Constant.b]))

        // Then
        XCTAssertEqual(decision.nextState.channels, [Constant.a, Constant.b])
        XCTAssertEqual(decision.nextState.phase, .loaded(isLoadingNext: false))
        XCTAssertEqual(decision.effects, [])
    }

    /// A snapshot identical to what is shown leaves the state untouched.
    func testIdenticalSnapshotIsIgnored() {
        // Given
        let state = loaded([Constant.a])

        // When / Then
        XCTAssertEqual(reduce(state, .channelsChanged([Constant.a])), Decision(nextState: state))
    }

    /// The list empties and fills again as snapshots arrive, without losing a page in flight.
    func testSnapshotMovesBetweenEmptyAndLoaded() {
        // Given
        let loadingNext = reduce(loaded([Constant.a], hasNext: true), .loadNextPage).nextState

        // When
        let emptied = reduce(loadingNext, .channelsChanged([])).nextState
        let refilled = reduce(emptied, .channelsChanged([Constant.b])).nextState

        // Then
        XCTAssertEqual(emptied.phase, .empty)
        XCTAssertEqual(refilled.phase, .loaded(isLoadingNext: false))
        XCTAssertEqual(reduce(loadingNext, .channelsChanged([Constant.b])).nextState.phase, .loaded(isLoadingNext: true))
    }

    // MARK: - Leave

    /// Leaving marks the channel busy and asks to leave it.
    func testLeaveMarksPendingAndRequestsLeave() {
        // Given
        let state = loaded([Constant.a])

        // When
        let decision = reduce(state, .leave(channelID: "a"))

        // Then
        XCTAssertEqual(decision.nextState.pendingActionChannelIDs, ["a"])
        XCTAssertEqual(decision.effects, [.leave(Constant.a)])
    }

    /// A second tap while a leave is in flight is ignored.
    func testLeaveIsIgnoredWhilePending() {
        // Given
        let state = reduce(loaded([Constant.a]), .leave(channelID: "a")).nextState

        // When / Then
        XCTAssertEqual(reduce(state, .leave(channelID: "a")), Decision(nextState: state))
    }

    /// A channel that cannot be left, or is not listed, is never left.
    func testLeaveIsIgnoredWhenNotAllowedOrUnknown() {
        // Given
        let state = loaded([channel("a", canLeave: false)])

        // When / Then
        XCTAssertEqual(reduce(state, .leave(channelID: "a")), Decision(nextState: state))
        XCTAssertEqual(reduce(state, .leave(channelID: "missing")), Decision(nextState: state))
    }

    /// A successful leave tells the host, even if the snapshot already removed the row.
    func testLeaveSuccessNotifiesWithTheChannel() {
        // Given
        let leaving = reduce(loaded([Constant.a, Constant.b]), .leave(channelID: "a")).nextState
        let removed = reduce(leaving, .channelsChanged([Constant.b])).nextState

        // When
        let decision = reduce(removed, .leaveFinished(Constant.a, failure: nil))

        // Then
        XCTAssertTrue(decision.nextState.pendingActionChannelIDs.isEmpty)
        XCTAssertEqual(decision.nextState.channels, [Constant.b])
        XCTAssertEqual(decision.effects, [.notify(.leftChannel(Constant.a))])
    }

    /// A failed leave reports the error and releases the channel.
    func testLeaveFailureNotifiesAndClearsPending() {
        // Given
        let state = reduce(loaded([Constant.a]), .leave(channelID: "a")).nextState

        // When
        let decision = reduce(state, .leaveFinished(Constant.a, failure: Constant.message))

        // Then
        XCTAssertTrue(decision.nextState.pendingActionChannelIDs.isEmpty)
        XCTAssertEqual(decision.nextState.channels, [Constant.a])
        XCTAssertEqual(decision.effects, [.notify(.failed(message: Constant.message))])
    }

    /// A completion for a channel that is not pending is a stray and is dropped.
    func testLeaveFinishedIsIgnoredWhenNotPending() {
        // Given
        let state = loaded([Constant.a])

        // When / Then
        XCTAssertEqual(reduce(state, .leaveFinished(Constant.a, failure: nil)), Decision(nextState: state))
    }

    // MARK: - Notifications

    /// Muting an unmuted channel asks for `.off`, and unmuting asks for `.all`.
    func testToggleNotificationsRequestsTheOppositeLevel() {
        // Given
        let unmuted = channel("a", notificationLevel: .all)
        let muted = channel("b", notificationLevel: .off)
        let state = loaded([unmuted, muted])

        // When
        let mute = reduce(state, .toggleNotifications(channelID: "a"))
        let unmute = reduce(state, .toggleNotifications(channelID: "b"))

        // Then
        XCTAssertEqual(mute.nextState.pendingActionChannelIDs, ["a"])
        XCTAssertEqual(mute.effects, [.setNotificationLevel(.off, channel: unmuted)])
        XCTAssertEqual(unmute.effects, [.setNotificationLevel(.all, channel: muted)])
    }

    /// A channel whose level cannot change, one that is busy, or one that is not listed is
    /// left alone.
    func testToggleNotificationsIsIgnoredWhenNotAllowedPendingOrUnknown() {
        // Given
        let fixed = loaded([channel("a", notificationLevel: nil)])
        let pending = reduce(loaded([Constant.a]), .leave(channelID: "a")).nextState

        // When / Then
        XCTAssertEqual(reduce(fixed, .toggleNotifications(channelID: "a")), Decision(nextState: fixed))
        XCTAssertEqual(reduce(pending, .toggleNotifications(channelID: "a")), Decision(nextState: pending))
        XCTAssertEqual(reduce(fixed, .toggleNotifications(channelID: "missing")), Decision(nextState: fixed))
    }

    /// A successful toggle tells the host, handing over the channel with its new level.
    func testNotificationLevelSetNotifiesWithTheNewLevel() {
        // Given
        let state = reduce(loaded([Constant.a]), .toggleNotifications(channelID: "a")).nextState
        var updated = Constant.a
        updated.notificationLevel = .off

        // When
        let decision = reduce(state, .notificationLevelSet(.off, channel: Constant.a, failure: nil))

        // Then
        XCTAssertTrue(decision.nextState.pendingActionChannelIDs.isEmpty)
        XCTAssertEqual(decision.nextState.channels, [Constant.a])
        XCTAssertEqual(decision.effects, [.notify(.notificationLevelChanged(updated))])
    }

    /// A failed toggle reports the error and releases the channel.
    func testNotificationLevelSetFailureNotifies() {
        // Given
        let state = reduce(loaded([Constant.a]), .toggleNotifications(channelID: "a")).nextState

        // When
        let decision = reduce(state, .notificationLevelSet(.off, channel: Constant.a, failure: Constant.message))

        // Then
        XCTAssertTrue(decision.nextState.pendingActionChannelIDs.isEmpty)
        XCTAssertEqual(decision.effects, [.notify(.failed(message: Constant.message))])
    }

    /// A completion for a channel that is not pending is a stray and is dropped.
    func testNotificationLevelSetIsIgnoredWhenNotPending() {
        // Given
        let state = loaded([Constant.a])

        // When / Then
        XCTAssertEqual(
            reduce(state, .notificationLevelSet(.off, channel: Constant.a, failure: nil)),
            Decision(nextState: state)
        )
    }

    // MARK: - Helpers

    private func reduce(_ state: ChannelListState, _ input: ChannelListReducer.Input) -> Decision {
        ChannelListReducer().reduce(state, input)
    }

    private func withPhase(_ phase: ChannelListState.Phase) -> ChannelListState {
        var state = ChannelListState()
        state.phase = phase
        return state
    }

    private func loaded(_ channels: [ChatChannel], hasNext: Bool = false) -> ChannelListState {
        reduce(withPhase(.loading), .pageLoaded(ChannelListPage(channels: channels, hasNext: hasNext))).nextState
    }

    private func failedNextPage() -> ChannelListState {
        let loadingNext = reduce(loaded([Constant.a], hasNext: true), .loadNextPage).nextState
        return reduce(loadingNext, .pageFailed(message: Constant.message)).nextState
    }
}

private func channel(
    _ id: String,
    notificationLevel: ChatChannel.NotificationLevel? = .all,
    canLeave: Bool = true
) -> ChatChannel {
    ChannelFixtures.channel(id: id) {
        $0.name = id
        $0.notificationLevel = notificationLevel
        $0.canLeave = canLeave
    }
}
