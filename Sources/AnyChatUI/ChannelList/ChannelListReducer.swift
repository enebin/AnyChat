import AnyChatCore

/// A one-shot event handed to the host app's callbacks.
nonisolated enum ChannelListEvent: Equatable, Sendable {
    case leftChannel(ChatChannel)
    /// Carries the channel with its new level.
    case notificationLevelChanged(ChatChannel)
    case failed(message: String)
}

/// The channel list's transition rules. Pure: it never runs anything itself.
nonisolated struct ChannelListReducer {
    enum Input: Equatable, Sendable {
        case start
        case retry
        case refresh
        case loadNextPage
        case retryNextPage
        case leave(channelID: String)
        case toggleNotifications(channelID: String)
        case channelsChanged([ChatChannel])
        case pageLoaded(ChannelListPage)
        case pageFailed(message: String)
        case leaveFinished(ChatChannel, failure: String?)
        case notificationLevelSet(ChatChannel.NotificationLevel, channel: ChatChannel, failure: String?)
    }

    enum Effect: Equatable, Sendable {
        /// Opens a fresh observation and loads its first page.
        case startObserving
        case loadMore
        case leave(ChatChannel)
        case setNotificationLevel(ChatChannel.NotificationLevel, channel: ChatChannel)
        case notify(ChannelListEvent)
    }

    typealias Decision = AnyChatUI.Decision<ChannelListState, Effect>

    func reduce(_ state: ChannelListState, _ input: Input) -> Decision {
        switch input {
        case .start:
            // Observation outlives the view: coming back from a pushed screen must not reload.
            guard state.phase == .idle else {
                return Decision(nextState: state)
            }
            return beginObserving(state)

        case .retry:
            guard case .error = state.phase else {
                return Decision(nextState: state)
            }
            return beginObserving(state)

        case .refresh:
            guard !state.isRefreshing, !state.isLoading else {
                return Decision(nextState: state)
            }
            var next = state
            next.isRefreshing = true
            next.loadMoreError = nil
            return Decision(nextState: next, effects: [.startObserving])

        case .loadNextPage:
            guard state.canLoadNextPage else {
                return Decision(nextState: state)
            }
            return beginNextPage(state)

        case .retryNextPage:
            guard state.canRetryNextPage else {
                return Decision(nextState: state)
            }
            return beginNextPage(state)

        case let .leave(channelID):
            guard let channel = state.channel(for: channelID),
                  channel.canLeave,
                  !state.pendingActionChannelIDs.contains(channelID) else {
                return Decision(nextState: state)
            }
            var next = state
            next.pendingActionChannelIDs.insert(channelID)
            return Decision(nextState: next, effects: [.leave(channel)])

        case let .toggleNotifications(channelID):
            guard let channel = state.channel(for: channelID),
                  let level = channel.notificationLevel,
                  !state.pendingActionChannelIDs.contains(channelID) else {
                return Decision(nextState: state)
            }
            var next = state
            next.pendingActionChannelIDs.insert(channelID)
            return Decision(
                nextState: next,
                effects: [.setNotificationLevel(level == .off ? .all : .off, channel: channel)]
            )

        case let .channelsChanged(channels):
            return applySnapshot(channels, to: state)

        case let .pageLoaded(page):
            var next = state
            next.channels = page.channels
            next.hasNext = page.hasNext
            next.loadMoreError = nil
            next.phase = page.channels.isEmpty ? .empty : .loaded(isLoadingNext: false)
            next.isRefreshing = false
            return Decision(nextState: next)

        case let .pageFailed(message):
            return applyPageFailure(message, to: state)

        case let .leaveFinished(channel, failure):
            guard state.pendingActionChannelIDs.contains(channel.id) else {
                return Decision(nextState: state)
            }
            var next = state
            next.pendingActionChannelIDs.remove(channel.id)
            // On success the row itself disappears with the next snapshot.
            let event: ChannelListEvent = failure.map { .failed(message: $0) } ?? .leftChannel(channel)
            return Decision(nextState: next, effects: [.notify(event)])

        case let .notificationLevelSet(level, channel, failure):
            guard state.pendingActionChannelIDs.contains(channel.id) else {
                return Decision(nextState: state)
            }
            var next = state
            next.pendingActionChannelIDs.remove(channel.id)
            // The new level reaches the rows with the snapshot the repository publishes.
            var updated = channel
            updated.notificationLevel = level
            let event: ChannelListEvent = failure.map { .failed(message: $0) } ?? .notificationLevelChanged(updated)
            return Decision(nextState: next, effects: [.notify(event)])
        }
    }

    /// Starts a fresh observation: the list is cleared and the whole screen shows a spinner.
    private func beginObserving(_ state: ChannelListState) -> Decision {
        var next = state
        next.phase = .loading
        next.loadMoreError = nil
        next.hasNext = true
        next.channels = []
        next.isRefreshing = false
        return Decision(nextState: next, effects: [.startObserving])
    }

    private func beginNextPage(_ state: ChannelListState) -> Decision {
        var next = state
        next.loadMoreError = nil
        next.phase = .loaded(isLoadingNext: true)
        return Decision(nextState: next, effects: [.loadMore])
    }

    private func applySnapshot(_ channels: [ChatChannel], to state: ChannelListState) -> Decision {
        guard state.channels != channels else {
            return Decision(nextState: state)
        }

        var next = state
        next.channels = channels

        switch state.phase {
        case .loaded, .empty:
            next.phase = channels.isEmpty
                ? .empty
                : .loaded(isLoadingNext: state.phase == .loaded(isLoadingNext: true))
        case .idle, .loading, .error:
            break
        }
        return Decision(nextState: next)
    }

    private func applyPageFailure(_ message: String, to state: ChannelListState) -> Decision {
        var next = state

        if state.isRefreshing {
            next.isRefreshing = false
            return Decision(nextState: next, effects: [.notify(.failed(message: message))])
        }

        if state.phase == .loading {
            next.channels = []
            next.phase = .error(message)
            return Decision(nextState: next)
        }

        next.phase = .loaded(isLoadingNext: false)
        next.loadMoreError = message
        return Decision(nextState: next)
    }
}
