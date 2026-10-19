import Foundation
import AnyChatCore

/// Owns the channel screen's state and runs the effects `ChannelReducer` asks for.
///
/// `state` changes in exactly one place: `send(_:)` storing the reducer's next state. Effects
/// report back by sending new inputs. Late results are filtered by `Task` identity: a task
/// replaced or cancelled in its `TaskBag` slot checks `Task.isCancelled` before sending.
@MainActor
@Observable
final class ChannelStore {
    /// `nonisolated` so it satisfies `TaskBag`'s `Sendable` requirement.
    nonisolated enum TaskID: Hashable, Sendable {
        case observing
        case page
        /// Keyed by the picked items so two picks prepare side by side.
        case preparing([AttachmentSource])
    }

    static let channelUnavailableMessage = "This channel is no longer available."
    static let attachmentFailureMessage = "The selected files could not be attached."

    private(set) var state = ChannelState()
    /// The rendered form of `state.messages`. All comparison and diffing happens here.
    private(set) var rows: [MessageRowState] = []

    @ObservationIgnored
    private var rowsBuiltAt: Date?

    @ObservationIgnored
    private let reducer = ChannelReducer()

    @ObservationIgnored
    private let repository: any ChannelRepository

    @ObservationIgnored
    private let currentUserID: String?

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private let prepareAttachments: @MainActor ([AttachmentSource]) async throws -> [ChatOutgoingAttachment]

    @ObservationIgnored
    private let discardAttachments: @MainActor ([ChatOutgoingAttachment]) -> Void

    @ObservationIgnored
    private let tasks = TaskBag<TaskID>()

    init(
        repository: any ChannelRepository,
        currentUserID: String?,
        canSendMessage: Bool,
        canReply: Bool = false,
        now: @escaping () -> Date = Date.init,
        prepareAttachments: @escaping @MainActor ([AttachmentSource]) async throws -> [ChatOutgoingAttachment] = {
            try await AttachmentPreparer().prepare($0)
        },
        discardAttachments: @escaping @MainActor ([ChatOutgoingAttachment]) -> Void = {
            AttachmentPreparer().discard($0)
        }
    ) {
        self.repository = repository
        self.currentUserID = currentUserID
        self.now = now
        self.prepareAttachments = prepareAttachments
        self.discardAttachments = discardAttachments
        state.canSendMessage = canSendMessage
        state.canReply = canReply
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func send(_ input: ChannelReducer.Input) {
        let decision = reducer.reduce(state, input)
        store(decision.nextState)
        for effect in decision.effects {
            run(effect)
        }
    }

    // MARK: - State

    private func store(_ next: ChannelState) {
        let previous = state
        state = next

        if previous.messages != next.messages {
            let now = now()
            // Date separators name today and yesterday, so a new day redraws all.
            let isSameDay = rowsBuiltAt.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
            rows = MessageRowState.rows(
                for: next.messages,
                currentUserID: currentUserID,
                now: now,
                reusing: isSameDay ? rows : []
            )
            rowsBuiltAt = now
        }
    }

    // MARK: - Effects

    private func run(_ effect: ChannelReducer.Effect) {
        switch effect {
        case .startObserving:
            startObserving()
        case .loadPrevious:
            loadPrevious()
        case let .sendText(text, replyTo):
            repository.sendMessage(text: text, replyTo: replyTo)
        case let .prepareAttachments(sources, replyTo):
            prepare(sources, replyTo: replyTo)
        case let .sendAttachments(attachments, replyTo):
            repository.sendMessage(attachments: attachments, replyTo: replyTo)
        case let .discardAttachments(attachments):
            discardAttachments(attachments)
        case let .resendMessage(id):
            repository.resendMessage(id: id)
        case let .removeFailedMessage(id):
            repository.removeFailedMessage(id: id)
        }
    }

    /// The task in the `.observing` slot *is* the identity of the current observation: starting
    /// another one replaces it, and a replaced task never sends. Cancelling also ends the loop,
    /// which terminates the stream and releases the backend's resources.
    private func startObserving() {
        tasks.cancel(.page)

        tasks.start(.observing) { [weak self, repository] in
            let stream = repository.startObserving()

            let input: ChannelReducer.Input
            do {
                input = .pageLoaded(try await repository.loadPrevious())
            } catch is CancellationError {
                return
            } catch {
                input = .pageFailed(message: ChannelStore.message(for: error))
            }

            // Cancellation is cooperative, so a superseded observation still delivers its page.
            guard !Task.isCancelled else {
                return
            }
            self?.send(input)

            for await messages in stream {
                guard !Task.isCancelled, let self else {
                    return
                }
                send(.messagesChanged(messages))
            }

            // Nobody cancelled this observation, so the adapter ended it: the channel is gone. A
            // page still in flight must not turn the error back into a list.
            guard !Task.isCancelled, let self else {
                return
            }
            tasks.cancel(.page)
            send(.observationEnded(message: ChannelStore.channelUnavailableMessage))
        }
    }

    /// A channel that is gone reads the same whether the stream ended or a retry found it missing,
    /// so the user is not told to try again.
    private static func message(for error: any Error) -> String {
        if error as? ChannelRepositoryError == .channelNotFound {
            return channelUnavailableMessage
        }
        return ErrorMessage.text(for: error)
    }

    private func prepare(_ sources: [AttachmentSource], replyTo: String?) {
        let slot = TaskID.preparing(sources)
        tasks.start(slot) { [weak self, prepareAttachments, discardAttachments] in
            let input: ChannelReducer.Input
            do {
                input = .attachmentsPrepared(try await prepareAttachments(sources), replyTo: replyTo)
            } catch is CancellationError {
                return
            } catch {
                input = .attachmentsFailed(message: ChannelStore.attachmentFailureMessage)
            }

            // A pick of the very same items replaced this one, or the Store is gone. Nobody will
            // send these copies, so they are deleted here.
            guard !Task.isCancelled, let self else {
                if case let .attachmentsPrepared(attachments, _) = input {
                    discardAttachments(attachments)
                }
                return
            }
            send(input)
            // `TaskBag` keeps an entry until it is cancelled, and this key holds the picked items.
            tasks.cancel(slot)
        }
    }

    private func loadPrevious() {
        tasks.start(.page) { [weak self, repository] in
            let input: ChannelReducer.Input
            do {
                input = .pageLoaded(try await repository.loadPrevious())
            } catch is CancellationError {
                return
            } catch {
                input = .pageFailed(message: ChannelStore.message(for: error))
            }

            guard !Task.isCancelled else {
                return
            }
            self?.send(input)
        }
    }
}
