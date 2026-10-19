import SwiftUI

/// What the views of `ChannelView.messageLongPressOverlay(above:below:)` need to know about the
/// long-pressed message, the actions they can take, the long-press menu's default buttons, and a
/// way to close the overlay.
///
/// It carries the same state and actions as `MessageActionContext`, plus `dismiss()`. A button
/// you add does not close the overlay by itself, so call `dismiss()` when it finishes. Unlike
/// `MessageRowContext`, it carries actions, so it is not `Hashable`.
///
/// - Since: 1.0.0
public struct MessageOverlayContext {
    /// Whether the current user sent the message. See `MessageRowContext.isMine`.
    ///
    /// - Since: 1.0.0
    public var isMine: Bool { actions.isMine }

    /// Whether `resend()` sends the message now: it failed and the current user can send.
    ///
    /// - Since: 1.0.0
    public var canResend: Bool { actions.canResend }

    /// Whether `copy()` has text to copy: the message's text is not empty.
    ///
    /// - Since: 1.0.0
    public var canCopy: Bool { actions.canCopy }

    /// Whether `reply()` starts a reply to the message: `ChatChannel.canReply` is `true`, the user
    /// can send now, and the message is sent and is not a system message.
    ///
    /// - Since: 1.0.0
    public var canReply: Bool { actions.canReply }

    private let actions: MessageActionContext
    /// The same items, with actions that also close the overlay.
    private let defaultItemActions: MessageActionContext
    private let dismissAction: () -> Void

    init(actions: MessageActionContext, defaultItemActions: MessageActionContext, dismiss: @escaping () -> Void) {
        self.actions = actions
        self.defaultItemActions = defaultItemActions
        dismissAction = dismiss
    }

    /// The long-press menu's default buttons, fitted to the message: Retry (while `canResend`)
    /// and Remove for a failed message; for any other message, Reply (while `canReply`) and Copy
    /// (for a message with text). Each one closes the overlay after it acts. Put it in the
    /// `below:` closure to keep them.
    ///
    /// - Since: 1.0.0
    public var defaultItems: some View {
        defaultItemActions.defaultItems
    }

    var defaultItemsAreEmpty: Bool {
        defaultItemActions.defaultItemsAreEmpty
    }

    /// Closes the overlay, putting the bubble back in the list. Call it from your buttons when
    /// they finish.
    ///
    /// - Since: 1.0.0
    public func dismiss() {
        dismissAction()
    }

    /// Sends a failed message again. Does nothing unless `canResend` is `true`. Does not close
    /// the overlay.
    ///
    /// - Since: 1.0.0
    public func resend() {
        actions.resend()
    }

    /// Removes a failed message. Does nothing for a message that has not failed. Does not close
    /// the overlay.
    ///
    /// - Since: 1.0.0
    public func remove() {
        actions.remove()
    }

    /// Starts a reply to the message: the composer shows a reply bar, and the next message sent
    /// answers this one. Does nothing unless `canReply` is `true`. Does not close the overlay.
    ///
    /// - Since: 1.0.0
    public func reply() {
        actions.reply()
    }

    /// Copies the message's text to the general pasteboard. Does nothing unless `canCopy` is
    /// `true`. Does not close the overlay.
    ///
    /// - Since: 1.0.0
    public func copy() {
        actions.copy()
    }
}
