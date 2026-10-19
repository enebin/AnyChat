import Foundation
import AnyChatCore

/// Owns the channel list state and runs the effects `ChannelListReducer` asks for.
///
/// `state` changes in exactly one place: `send(_:)` storing the reducer's next state. Effects
/// report back by sending new inputs. Late results are filtered by `Task` identity: a task
/// replaced in its `TaskBag` slot is cancelled, and it checks `Task.isCancelled` before sending.
@MainActor
@Observable
final class ChannelListStore {
    /// An event waiting for the view to hand it to the host's callbacks.
    ///
    /// `id` tells two equal events apart, so the view reacts to each emission once.
    struct OutboundEvent: Equatable {
        let id: Int
        let event: ChannelListEvent
    }

    /// `nonisolated` so it satisfies `TaskBag`'s `Sendable` requirement.
    nonisolated enum TaskID: Hashable, Sendable {
        case observing
        case page
        case action(channelID: String)
    }

    static let genericErrorMessage = ErrorMessage.generic

    private(set) var state = ChannelListState()
    /// The rendered form of `state.channels`. All comparison and diffing happens here.
    private(set) var rows: [ChannelRowState] = []
    private(set) var outboundEvent: OutboundEvent?

    @ObservationIgnored
    private var lastEventID = 0

    /// Resumed once the refresh `refresh()` started has settled.
    @ObservationIgnored
    private var refreshWaiter: CheckedContinuation<Void, Never>?

    @ObservationIgnored
    private let reducer = ChannelListReducer()

    @ObservationIgnored
    private let repository: any ChannelListRepository

    @ObservationIgnored
    private let currentUserID: String?

    @ObservationIgnored
    private let options: ChannelListOptions

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private let tasks = TaskBag<TaskID>()

    init(
        repository: any ChannelListRepository,
        currentUserID: String?,
        options: ChannelListOptions = ChannelListOptions(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.currentUserID = currentUserID
        self.options = options
        self.now = now
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func send(_ input: ChannelListReducer.Input) {
        let decision = reducer.reduce(state, input)
        store(decision.nextState)
        for effect in decision.effects {
            run(effect)
        }
    }

    /// Stays suspended until the new first page settles, so `refreshable` keeps the system
    /// spinner up for exactly that long. Returns at once when the refresh was ignored.
    func refresh() async {
        send(.refresh)
        guard state.isRefreshing else {
            return
        }
        await withCheckedContinuation { refreshWaiter = $0 }
    }

    // MARK: - State

    private func store(_ next: ChannelListState) {
        let previous = state
        state = next

        if previous.channels != next.channels || previous.pendingActionChannelIDs != next.pendingActionChannelIDs {
            rows = makeRows()
        }

        // Every path that finishes or abandons a refresh clears the flag, so `refreshable`
        // never hangs onto its spinner.
        if !next.isRefreshing, let refreshWaiter {
            self.refreshWaiter = nil
            refreshWaiter.resume()
        }
    }

    private func makeRows() -> [ChannelRowState] {
        let timestamp = now()
        return state.channels.map { channel in
            ChannelRowState.make(
                channel: channel,
                currentUserID: currentUserID,
                now: timestamp,
                options: options,
                isActionPending: state.pendingActionChannelIDs.contains(channel.id)
            )
        }
    }

    // MARK: - Effects

    private func run(_ effect: ChannelListReducer.Effect) {
        switch effect {
        case .startObserving:
            startObserving()
        case .loadMore:
            loadMore()
        case let .leave(channel):
            leave(channel)
        case let .setNotificationLevel(level, channel):
            setNotificationLevel(level, of: channel)
        case let .notify(event):
            lastEventID += 1
            outboundEvent = OutboundEvent(id: lastEventID, event: event)
        }
    }

    /// The task in the `.observing` slot *is* the identity of the current observation: starting
    /// another one replaces it, and a replaced task never sends. Cancelling also ends the loop,
    /// which terminates the stream and releases the backend's resources. That is the only
    /// teardown path.
    private func startObserving() {
        tasks.cancel(.page)

        tasks.start(.observing) { [weak self, repository] in
            let stream = repository.startObserving()

            let input: ChannelListReducer.Input
            do {
                input = .pageLoaded(try await repository.loadMore())
            } catch is CancellationError {
                return
            } catch {
                input = .pageFailed(message: ErrorMessage.text(for: error))
            }

            // Cancellation is cooperative, so a superseded observation still delivers its page.
            guard !Task.isCancelled else {
                return
            }
            self?.send(input)

            for await channels in stream {
                guard !Task.isCancelled, let self else {
                    return
                }
                send(.channelsChanged(channels))
            }
        }
    }

    private func loadMore() {
        tasks.start(.page) { [weak self, repository] in
            let input: ChannelListReducer.Input
            do {
                input = .pageLoaded(try await repository.loadMore())
            } catch is CancellationError {
                return
            } catch {
                input = .pageFailed(message: ErrorMessage.text(for: error))
            }

            guard !Task.isCancelled else {
                return
            }
            self?.send(input)
        }
    }

    private func leave(_ channel: ChatChannel) {
        tasks.start(.action(channelID: channel.id)) { [weak self, repository] in
            let failure: String?
            do {
                try await repository.leave(channelID: channel.id)
                failure = nil
            } catch is CancellationError {
                return
            } catch {
                failure = ErrorMessage.text(for: error)
            }

            guard !Task.isCancelled else {
                return
            }
            self?.send(.leaveFinished(channel, failure: failure))
        }
    }

    private func setNotificationLevel(_ level: ChatChannel.NotificationLevel, of channel: ChatChannel) {
        tasks.start(.action(channelID: channel.id)) { [weak self, repository] in
            let failure: String?
            do {
                try await repository.setNotificationLevel(level, channelID: channel.id)
                failure = nil
            } catch is CancellationError {
                return
            } catch {
                failure = ErrorMessage.text(for: error)
            }

            guard !Task.isCancelled else {
                return
            }
            self?.send(.notificationLevelSet(level, channel: channel, failure: failure))
        }
    }
}

/// Hands a failure message to the host's `onError` callback as an `Error`.
nonisolated struct ChannelListError: LocalizedError, Equatable {
    let message: String

    var errorDescription: String? { message }
}
