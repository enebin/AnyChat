import AnyChatCore
import SwiftUI
import UIKit

/// Builds what each message signal shows: the long-press menu or overlay, and the failed-message
/// dialog.
///
/// The cell and the screen-level dialog build from the same value, so the two never disagree.
struct MessageSignals {
    enum Signal {
        case longPress
        case failedTap
        case doubleTap
    }

    enum DefaultItem: Equatable {
        case retry
        case remove
        case reply
        case copy
    }

    var longPress: ((ChatMessage, MessageActionContext) -> AnyView)?
    var failedTap: ((ChatMessage, MessageActionContext) -> AnyView)?
    var doubleTap: ((ChatMessage, MessageActionContext) -> Void)?
    /// When set, the long press shows these views in place of the menu.
    var overlay: ChannelSlots.MessageOverlayViews?
    var canSend = false
    /// The screen's rule for answering a message, read from the Store's state.
    var canReply: (String) -> Bool = { _ in false }
    var resend: (String) -> Void = { _ in }
    var remove: (String) -> Void = { _ in }
    var reply: (String) -> Void = { _ in }
    var openOverlay: (String) -> Void = { _ in }

    /// `nil` when the signal does not apply to the message, and when the default has nothing to
    /// show. A host closure may still turn out empty; the row checks its items before attaching
    /// anything.
    func content(for signal: Signal, message: ChatMessage, isMine: Bool) -> AnyView? {
        if message.content.isSystem {
            return nil
        }
        if signal == .failedTap, message.sendingStatus != .failed {
            return nil
        }
        let context = context(for: signal, message: message, isMine: isMine)
        if let host = host(for: signal) {
            return host(message, context)
        }
        guard !context.defaultItemsAreEmpty else {
            return nil
        }
        return AnyView(context.defaultItems)
    }

    /// Both overlay views together, for a cell to count before it offers the overlay. `nil` for
    /// system messages and while the host has not set the overlay. The views are only counted,
    /// so their context does not close anything.
    func overlayViews(for message: ChatMessage, isMine: Bool) -> AnyView? {
        guard let overlay, !message.content.isSystem else {
            return nil
        }
        let context = overlayContext(for: message, isMine: isMine, dismiss: {})
        return AnyView(Group {
            overlay.above(message, context)
            overlay.below(message, context)
        })
    }

    func overlayContext(for message: ChatMessage, isMine: Bool, dismiss: @escaping () -> Void) -> MessageOverlayContext {
        let actions = context(for: .longPress, message: message, isMine: isMine)
        let canResend = actions.canResend
        let canReply = actions.canReply
        let dismissing = MessageActionContext(
            isMine: isMine,
            canResend: canResend,
            canCopy: actions.canCopy,
            canReply: canReply,
            defaultItems: Self.defaultItems(for: .longPress, message: message, canSend: canSend, canReply: canReply),
            resend: { actions.resend(); dismiss() },
            remove: { actions.remove(); dismiss() },
            copy: { actions.copy(); dismiss() },
            reply: { actions.reply(); dismiss() }
        )
        return MessageOverlayContext(actions: actions, defaultItemActions: dismissing, dismiss: dismiss)
    }

    /// `nil` for system messages and while the host has not set a double tap, so no recognizer
    /// makes single taps wait.
    func doubleTapAction(for message: ChatMessage, isMine: Bool) -> (() -> Void)? {
        guard let doubleTap, !message.content.isSystem else {
            return nil
        }
        let context = context(for: .doubleTap, message: message, isMine: isMine)
        return { doubleTap(message, context) }
    }

    func context(for signal: Signal, message: ChatMessage, isMine: Bool) -> MessageActionContext {
        let canResend = Self.canResend(message, canSend: canSend)
        let text = Self.copyableText(of: message)
        let canReply = canReply(message.id)
        return MessageActionContext(
            isMine: isMine,
            canResend: canResend,
            canCopy: text != nil,
            canReply: canReply,
            defaultItems: Self.defaultItems(for: signal, message: message, canSend: canSend, canReply: canReply),
            resend: { if canResend { resend(message.id) } },
            remove: { remove(message.id) },
            copy: { if let text { UIPasteboard.general.string = text } },
            reply: { if canReply { reply(message.id) } }
        )
    }

    /// A failed message gets the design source's dialog items on both signals that show buttons;
    /// a long press on any other message offers Reply first, when it can be answered, and Copy
    /// when it has text. Double tap shows nothing.
    static func defaultItems(for signal: Signal, message: ChatMessage, canSend: Bool, canReply: Bool) -> [DefaultItem] {
        if signal == .doubleTap {
            return []
        }
        if message.sendingStatus == .failed {
            return canResend(message, canSend: canSend) ? [.retry, .remove] : [.remove]
        }
        guard signal == .longPress else {
            return []
        }
        return (canReply ? [.reply] : []) + (copyableText(of: message) != nil ? [.copy] : [])
    }

    static func canResend(_ message: ChatMessage, canSend: Bool) -> Bool {
        message.sendingStatus == .failed && canSend
    }

    static func copyableText(of message: ChatMessage) -> String? {
        guard case let .text(text) = message.content, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func host(for signal: Signal) -> ((ChatMessage, MessageActionContext) -> AnyView)? {
        switch signal {
        case .longPress: longPress
        case .failedTap: failedTap
        case .doubleTap: nil
        }
    }
}
