import AnyChatCore
import SwiftUI

struct ChannelBody: UIViewControllerRepresentable {
    let content: MessageListContent
    let slots: ChannelSlots
    let signals: MessageSignals
    let isEmpty: Bool
    let canSend: Bool
    let isUnavailable: Bool
    let replyingTo: ChatMessage?
    let replyBarText: ReplyBarText?
    let topInset: CGFloat
    let onReachTop: () -> Void
    let onRetry: () -> Void
    let onFailedMessageSelected: (ChatMessage) -> Void
    let onSend: (String) -> Void
    let onAttach: ([AttachmentSource]) -> Void
    let onAttachFailure: () -> Void
    let onCancelReply: () -> Void
    /// The message the long-press overlay lifts; its bubble's frame comes back through
    /// `onLiftedFrameChange`, in this view's coordinate space, and `nil` once it leaves the screen.
    let liftedMessageID: String?
    let onLiftedFrameChange: (CGRect?) -> Void

    func makeUIViewController(context: Context) -> ChannelBodyViewController {
        ChannelBodyViewController()
    }

    func updateUIViewController(_ controller: ChannelBodyViewController, context: Context) {
        controller.update(
            content: content,
            slots: slots,
            signals: signals,
            environment: Self.readingSystemSettings(context.environment),
            isEmpty: isEmpty,
            canSend: canSend,
            isUnavailable: isUnavailable,
            replyingTo: replyingTo,
            replyBarText: replyBarText,
            topInset: topInset,
            onReachTop: onReachTop,
            onRetry: onRetry,
            onFailedMessageSelected: onFailedMessageSelected,
            onSend: onSend,
            onAttach: onAttach,
            onAttachFailure: onAttachFailure,
            onCancelReply: onCancelReply,
            liftedMessageID: liftedMessageID,
            onLiftedFrameChange: onLiftedFrameChange
        )
    }

    /// `update` hands the hosted cells the environment they adopt in place of their own, and the
    /// composer its theme, but it reruns only when a `context.environment` key it reads changes.
    /// Colors resolve without such a read, so a switch to dark left the rows and the composer's
    /// + button light. Reading the settings the system changes while the screen is open reruns it.
    private static func readingSystemSettings(_ environment: EnvironmentValues) -> EnvironmentValues {
        _ = environment.colorScheme
        _ = environment.colorSchemeContrast
        _ = environment.dynamicTypeSize
        _ = environment.legibilityWeight
        return environment
    }

    static func dismantleUIViewController(_ controller: ChannelBodyViewController, coordinator: ()) {
        controller.stop()
    }
}
