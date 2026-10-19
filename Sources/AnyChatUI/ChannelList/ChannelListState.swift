import AnyChatCore

/// What the channel list screen needs to decide its next transition.
nonisolated struct ChannelListState: Equatable, Sendable {
    /// What the screen as a whole is doing.
    enum Phase: Equatable, Sendable {
        case idle
        case loading
        case loaded(isLoadingNext: Bool)
        case empty
        case error(String)
    }

    /// What the list footer shows.
    enum PaginationStatus: Equatable, Sendable {
        case done
        case loading
        case retry
    }

    var phase: Phase = .idle
    /// The latest snapshot, in list order.
    var channels: [ChatChannel] = []
    var hasNext = true
    var isRefreshing = false
    /// Set when loading a *later* page fails; the list stays on screen and the footer offers a retry.
    var loadMoreError: String?
    var pendingActionChannelIDs: Set<String> = []

    var isLoading: Bool { phase == .loading }

    /// Scrolling may trigger another page only when nothing else is in flight and the last
    /// attempt did not fail. A failed page waits for an explicit retry.
    var canLoadNextPage: Bool {
        phase == .loaded(isLoadingNext: false) && hasNext && loadMoreError == nil
    }

    var canRetryNextPage: Bool {
        phase == .loaded(isLoadingNext: false) && hasNext && loadMoreError != nil
    }

    var paginationStatus: PaginationStatus {
        if phase == .loaded(isLoadingNext: true) {
            return .loading
        }
        if loadMoreError != nil {
            return .retry
        }
        return .done
    }

    func channel(for channelID: String) -> ChatChannel? {
        channels.first { $0.id == channelID }
    }
}
