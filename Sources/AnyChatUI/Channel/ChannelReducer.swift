import AnyChatCore

/// The channel screen's transition rules. Pure: it never runs anything itself.
nonisolated struct ChannelReducer {
    enum Input: Equatable, Sendable {
        case start
        case retry
        case loadPreviousPage
        case retryPreviousPage
        /// The host passed a newer value of the same channel.
        case channelChanged(ChatChannel)
        case messagesChanged([ChatMessage])
        /// The observation ended without being cancelled, so the channel can no longer be shown.
        case observationEnded(message: String)
        case pageLoaded(MessagePage)
        case pageFailed(message: String)
        case sendText(String)
        case sendAttachments([AttachmentSource])
        /// `replyTo` is what the user was answering when they picked the files.
        case attachmentsPrepared([ChatOutgoingAttachment], replyTo: String?)
        case attachmentsFailed(message: String)
        case startReply(messageID: String)
        case cancelReply
        case dismissAttachmentError
        case resendMessage(id: String)
        case removeFailedMessage(id: String)
    }

    enum Effect: Equatable, Sendable {
        /// Opens a fresh observation and loads its latest page.
        case startObserving
        case loadPrevious
        case sendText(String, replyTo: String?)
        /// Copies picked items into files the adapter can upload, keeping the reply they answer.
        case prepareAttachments([AttachmentSource], replyTo: String?)
        case sendAttachments([ChatOutgoingAttachment], replyTo: String?)
        /// Deletes prepared copies that will never be sent.
        case discardAttachments([ChatOutgoingAttachment])
        case resendMessage(id: String)
        case removeFailedMessage(id: String)
    }

    typealias Decision = AnyChatUI.Decision<ChannelState, Effect>

    func reduce(_ state: ChannelState, _ input: Input) -> Decision {
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

        case .loadPreviousPage:
            guard state.canLoadPreviousPage else {
                return Decision(nextState: state)
            }
            return beginPreviousPage(state)

        case .retryPreviousPage:
            guard state.canRetryPreviousPage else {
                return Decision(nextState: state)
            }
            return beginPreviousPage(state)

        case let .channelChanged(channel):
            guard channel.canSendMessage != state.canSendMessage || channel.canReply != state.canReply else {
                return Decision(nextState: state)
            }
            var next = state
            next.canSendMessage = channel.canSendMessage
            next.canReply = channel.canReply
            return Decision(nextState: clearingUnanswerableReply(next))

        case let .messagesChanged(messages):
            let decision = applySnapshot(messages, to: state)
            return Decision(nextState: clearingUnanswerableReply(decision.nextState), effects: decision.effects)

        case let .observationEnded(message):
            switch state.phase {
            case .loading, .loaded, .empty:
                var next = state
                next.phase = .error(message)
                next.messages = []
                next.loadPreviousError = nil
                next.replyingToID = nil
                return Decision(nextState: next)
            case .idle, .error:
                return Decision(nextState: state)
            }

        case let .pageLoaded(page):
            switch state.phase {
            case .loading, .loaded(isLoadingPrevious: true):
                var next = state
                next.messages = page.messages
                next.hasPrevious = page.hasPrevious
                next.loadPreviousError = nil
                next.phase = page.messages.isEmpty ? .empty : .loaded(isLoadingPrevious: false)
                return Decision(nextState: clearingUnanswerableReply(next))
            case .idle, .loaded(isLoadingPrevious: false), .empty, .error:
                // Nothing is waiting for a page, so this one is late.
                return Decision(nextState: state)
            }

        case let .pageFailed(message):
            switch state.phase {
            case .loading:
                var next = state
                next.messages = []
                next.phase = .error(message)
                return Decision(nextState: next)
            case .loaded(isLoadingPrevious: true):
                var next = state
                next.phase = .loaded(isLoadingPrevious: false)
                next.loadPreviousError = message
                return Decision(nextState: next)
            case .idle, .loaded(isLoadingPrevious: false), .empty, .error:
                return Decision(nextState: state)
            }

        case let .sendText(text):
            guard state.canSend, !text.isEmpty else {
                return Decision(nextState: state)
            }
            var next = state
            next.replyingToID = nil
            return Decision(nextState: next, effects: [.sendText(text, replyTo: state.replyingToID)])

        case let .sendAttachments(sources):
            guard state.canSend, !sources.isEmpty else {
                return Decision(nextState: state)
            }
            // Cleared at pick time, so a reply started while files are copied is not attached to them.
            var next = state
            next.replyingToID = nil
            return Decision(nextState: next, effects: [.prepareAttachments(sources, replyTo: state.replyingToID)])

        case let .attachmentsPrepared(attachments, replyTo):
            guard !attachments.isEmpty else {
                return Decision(nextState: state)
            }
            // The list may have gone, or sending turned off, while copying.
            guard state.canSend else {
                return Decision(nextState: state, effects: [.discardAttachments(attachments)])
            }
            // The original may have been deleted, or replies turned off, while copying. The user
            // picked the files to send, so they still go, as an ordinary message.
            let target = replyTo.flatMap { state.isReplyTarget($0) ? $0 : nil }
            return Decision(nextState: state, effects: [.sendAttachments(attachments, replyTo: target)])

        case let .startReply(messageID):
            guard state.canAnswer(messageID), state.replyingToID != messageID else {
                return Decision(nextState: state)
            }
            var next = state
            next.replyingToID = messageID
            return Decision(nextState: next)

        case .cancelReply:
            guard state.replyingToID != nil else {
                return Decision(nextState: state)
            }
            var next = state
            next.replyingToID = nil
            return Decision(nextState: next)

        case let .attachmentsFailed(message):
            var next = state
            next.attachmentError = message
            return Decision(nextState: next)

        case .dismissAttachmentError:
            guard state.attachmentError != nil else {
                return Decision(nextState: state)
            }
            var next = state
            next.attachmentError = nil
            return Decision(nextState: next)

        case let .resendMessage(id):
            guard state.canSend, hasFailedMessage(id, in: state) else {
                return Decision(nextState: state)
            }
            return Decision(nextState: state, effects: [.resendMessage(id: id)])

        case let .removeFailedMessage(id):
            // Removing sends nothing, so a message that failed in a channel the user can no
            // longer send to can still be removed.
            guard state.isShowingList, hasFailedMessage(id, in: state) else {
                return Decision(nextState: state)
            }
            return Decision(nextState: state, effects: [.removeFailedMessage(id: id)])
        }
    }

    private func clearingUnanswerableReply(_ state: ChannelState) -> ChannelState {
        guard let id = state.replyingToID, !state.isReplyTarget(id) else {
            return state
        }
        var next = state
        next.replyingToID = nil
        return next
    }

    private func hasFailedMessage(_ id: String, in state: ChannelState) -> Bool {
        state.messages.contains { $0.id == id && $0.sendingStatus == .failed }
    }

    /// Starts a fresh observation: the list is cleared and the whole screen shows a spinner.
    private func beginObserving(_ state: ChannelState) -> Decision {
        var next = state
        next.phase = .loading
        next.messages = []
        next.hasPrevious = true
        next.loadPreviousError = nil
        next.replyingToID = nil
        return Decision(nextState: next, effects: [.startObserving])
    }

    private func beginPreviousPage(_ state: ChannelState) -> Decision {
        var next = state
        next.loadPreviousError = nil
        next.phase = .loaded(isLoadingPrevious: true)
        return Decision(nextState: next, effects: [.loadPrevious])
    }

    private func applySnapshot(_ messages: [ChatMessage], to state: ChannelState) -> Decision {
        switch state.phase {
        case .loaded, .empty:
            guard state.messages != messages else {
                return Decision(nextState: state)
            }
            var next = state
            next.messages = messages
            next.phase = messages.isEmpty
                ? .empty
                : .loaded(isLoadingPrevious: state.phase == .loaded(isLoadingPrevious: true))
            return Decision(nextState: next)
        case .idle, .loading, .error:
            // The list is not on screen before the first page, and that page already holds
            // anything a snapshot sent meanwhile.
            return Decision(nextState: state)
        }
    }
}
