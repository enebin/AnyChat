import AnyChatCore

/// What the channel screen needs to decide its next transition.
nonisolated struct ChannelState: Equatable, Sendable {
    /// What the screen as a whole is doing.
    enum Phase: Equatable, Sendable {
        case idle
        case loading
        case loaded(isLoadingPrevious: Bool)
        case empty
        case error(String)
    }

    var phase: Phase = .idle
    /// The latest snapshot, oldest first.
    var messages: [ChatMessage] = []
    var hasPrevious = true
    /// Set when loading an *earlier* page fails; the list stays on screen and offers a retry.
    var loadPreviousError: String?
    /// Taken from the channel when the Store is made, then from each newer value the host passes.
    var canSendMessage = true
    /// Taken from the channel like `canSendMessage`; without it no message can be answered.
    var canReply = false
    /// The message the user is answering. Cleared when it is sent or can no longer be answered.
    var replyingToID: String?
    /// Set when picked attachments could not be prepared; the screen shows it until dismissed.
    var attachmentError: String?

    var isShowingList: Bool {
        switch phase {
        case .loaded, .empty:
            true
        case .idle, .loading, .error:
            false
        }
    }

    /// The one rule for sending: the Reducer ignores sends without it and the composer is
    /// disabled, so a tap the Reducer would ignore cannot happen.
    var canSend: Bool {
        canSendMessage && isShowingList
    }

    /// Scrolling may trigger another page only when nothing else is in flight and the last
    /// attempt did not fail. A failed page waits for an explicit retry.
    var canLoadPreviousPage: Bool {
        phase == .loaded(isLoadingPrevious: false) && hasPrevious && loadPreviousError == nil
    }

    /// The one rule for starting a reply, shared by the menu, the swipe, and the Reducer.
    func canAnswer(_ messageID: String) -> Bool {
        canSend && isReplyTarget(messageID)
    }

    /// A message a reply may point to: replies are on, and it is a sent, non-system message this
    /// screen holds. A pending or failed message may not exist on the backend yet. Unlike
    /// `canAnswer` it does not need `canSend`, so a reply waits while only sending is off.
    func isReplyTarget(_ messageID: String) -> Bool {
        canReply && messages.contains { $0.id == messageID && $0.sendingStatus == nil && !$0.content.isSystem }
    }

    var canRetryPreviousPage: Bool {
        phase == .loaded(isLoadingPrevious: false) && hasPrevious && loadPreviousError != nil
    }
}
