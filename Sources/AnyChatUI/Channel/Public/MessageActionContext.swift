import SwiftUI
import AnyChatCore

/// What a message signal's closure needs to know about its message, the actions it can take,
/// and the package's default buttons for that signal.
///
/// `messageContextMenu(_:)`, `failedMessageActions(_:)`, and `onMessageDoubleTapped(_:)` pass
/// one to the host's closure together with the message. Unlike `MessageRowContext`, it carries
/// actions, so it is not `Hashable`. The views of `ChannelView.messageLongPressOverlay(above:below:)`
/// receive `MessageOverlayContext` instead, which adds `dismiss()` to the same state and actions.
///
/// - Since: 1.0.0
public struct MessageActionContext {
    /// Whether the current user sent the message. See `MessageRowContext.isMine`.
    ///
    /// - Since: 1.0.0
    public let isMine: Bool

    /// Whether `resend()` sends the message now: it failed and the current user can send.
    ///
    /// - Since: 1.0.0
    public let canResend: Bool

    /// Whether `copy()` has text to copy: the message's text is not empty.
    ///
    /// - Since: 1.0.0
    public let canCopy: Bool

    /// Whether `reply()` starts a reply to the message: `ChatChannel.canReply` is `true`, the user
    /// can send now, and the message is sent and is not a system message.
    ///
    /// - Since: 1.0.0
    public let canReply: Bool

    private let defaultItemList: [MessageSignals.DefaultItem]
    private let resendAction: () -> Void
    private let removeAction: () -> Void
    private let copyAction: () -> Void
    private let replyAction: () -> Void

    init(
        isMine: Bool,
        canResend: Bool,
        canCopy: Bool,
        canReply: Bool,
        defaultItems: [MessageSignals.DefaultItem],
        resend: @escaping () -> Void,
        remove: @escaping () -> Void,
        copy: @escaping () -> Void,
        reply: @escaping () -> Void
    ) {
        self.isMine = isMine
        self.canResend = canResend
        self.canCopy = canCopy
        self.canReply = canReply
        defaultItemList = defaultItems
        resendAction = resend
        removeAction = remove
        copyAction = copy
        replyAction = reply
    }

    /// The buttons the screen shows for this signal when you do not set it, fitted to the
    /// message: Retry (while `canResend`) and Remove for a failed message, and on a long press
    /// Reply (while `canReply`) and Copy (for a message with text) for any other message. Empty
    /// for a double tap, which shows nothing. Put it in your closure to keep them.
    ///
    /// - Since: 1.0.0
    public var defaultItems: some View {
        DefaultMessageItems(items: defaultItemList, context: self)
    }

    var defaultItemsAreEmpty: Bool {
        defaultItemList.isEmpty
    }

    /// Sends a failed message again. Does nothing unless `canResend` is `true`.
    ///
    /// - Since: 1.0.0
    public func resend() {
        resendAction()
    }

    /// Removes a failed message. Does nothing for a message that has not failed.
    ///
    /// - Since: 1.0.0
    public func remove() {
        removeAction()
    }

    /// Starts a reply to the message: the composer shows a reply bar, and the next message sent
    /// answers this one. Does nothing unless `canReply` is `true`.
    ///
    /// - Since: 1.0.0
    public func reply() {
        replyAction()
    }

    /// Copies the message's text to the general pasteboard. Does nothing unless `canCopy` is
    /// `true`.
    ///
    /// - Since: 1.0.0
    public func copy() {
        copyAction()
    }
}

/// Text only: the confirmation dialog draws no icons, and a button with an icon surfaces there as
/// two nested accessibility elements.
private struct DefaultMessageItems: View {
    let items: [MessageSignals.DefaultItem]
    let context: MessageActionContext

    var body: some View {
        ForEach(items, id: \.self) { item in
            switch item {
            case .retry:
                Button("Retry") { context.resend() }
            case .remove:
                Button("Remove", role: .destructive) { context.remove() }
            case .reply:
                Button("Reply") { context.reply() }
            case .copy:
                Button("Copy") { context.copy() }
            }
        }
    }
}
