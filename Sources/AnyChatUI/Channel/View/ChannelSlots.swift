import AnyChatCore
import SwiftUI

/// The custom views and callbacks a host app has plugged into the channel screen.
///
/// Stored on the view itself rather than in a global registry, so one screen's customization
/// never leaks into another.
struct ChannelSlots {
    var header: ((ChatChannel) -> AnyView)?
    var emptyState: ((ComposerContext) -> AnyView)?
    var messageRow: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageContent: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageAccessory: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageReplyQuote: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageAvatar: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageSenderName: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageTime: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageBubbleBackground: ((ChatMessage, MessageRowContext) -> AnyView)?
    var messageDateSeparator: ((MessageDateSeparatorContext) -> AnyView)?
    var messageBubbleLayout = MessageBubbleLayout()

    var customMessageRows: [(ChatMessage, MessageRowContext) -> AnyView?] = []
    var customMessageContents: [(ChatMessage, MessageRowContext) -> AnyView?] = []

    var attachmentSelected: ((ChatAttachment, ChatMessage) -> Void)?
    var messageContextMenu: ((ChatMessage, MessageActionContext) -> AnyView)?
    var failedMessageActions: ((ChatMessage, MessageActionContext) -> AnyView)?
    var messageDoubleTapped: ((ChatMessage, MessageActionContext) -> Void)?
    var messageLongPressOverlay: MessageOverlayViews?
    var composerPlaceholder: String?
    var composerLeadingItems: ((ComposerContext) -> AnyView)?
    var composerTrailingItems: ((ComposerContext) -> AnyView)?
    var composerItemsInsideField = false
    var composerSendButtonLabel: (() -> AnyView)?
    var composerStopButton: ComposerStopButton?
    var composer: ((ComposerContext) -> AnyView)?
    var composerReplyBar: ((ChatMessage, ComposerContext) -> AnyView)?
    var composerBackground: (() -> AnyView)?
    var jumpToLatestButton: ((@escaping () -> Void) -> AnyView)?
    var scrollBehavior = MessageScrollBehavior.followsLatest

    /// `nil` keeps the default text bubble's value.
    struct MessageBubbleLayout: Equatable {
        var insets: EdgeInsets?
        var maxWidth: CGFloat?
    }

    struct ComposerStopButton {
        let isResponding: Bool
        let action: () -> Void
    }

    struct MessageOverlayViews {
        let above: (ChatMessage, MessageOverlayContext) -> AnyView
        let below: (ChatMessage, MessageOverlayContext) -> AnyView
    }

    func row(for message: ChatMessage, context: MessageRowContext) -> AnyView? {
        for renderer in customMessageRows.reversed() {
            if let view = renderer(message, context) { return view }
        }
        return messageRow?(message, context)
    }

    func content(for message: ChatMessage, context: MessageRowContext) -> AnyView? {
        for renderer in customMessageContents.reversed() {
            if let view = renderer(message, context) { return view }
        }
        return messageContent?(message, context)
    }
}
