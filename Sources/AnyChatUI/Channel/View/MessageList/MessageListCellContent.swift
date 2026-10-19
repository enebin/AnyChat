import AnyChatCore
import SwiftUI

struct MessageListRow: View {
    let row: MessageRowState
    let isFirst: Bool
    let presentation: MessageListCellPresentation

    /// The row fills its cell's content view, so frames in this space are frames in the cell.
    nonisolated static let cellSpace = "MessageListRow.cell"

    private let itemSpacing: CGFloat = 10
    private let runSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: itemSpacing) {
            if let separator = row.dateSeparator {
                dateSeparator(separator)
            }
            messageRow
                .modifier(MessageDoubleTap(
                    action: presentation.signals.doubleTapAction(for: row.message, isMine: row.isMine)
                ))
                .modifier(FailedMessageTap(
                    message: row.message,
                    dialog: presentation.signals.content(for: .failedTap, message: row.message, isMine: row.isMine),
                    onSelect: presentation.onFailedMessageSelected
                ))
        }
        .padding(.top, isFirst ? 0 : (row.joinsPrevious ? runSpacing : itemSpacing))
        .modifier(ReplyAccessibilityAction(isAvailable: presentation.signals.canReply(row.id)) { [presentation, id = row.id] in
            if presentation.signals.canReply(id) {
                presentation.signals.reply(id)
            }
        })
        .environment(\.self, presentation.environment)
        .coordinateSpace(.named(Self.cellSpace))
    }

    /// Resolved first so a closure that returns nothing removes the separator and its spacing.
    @ViewBuilder
    private func dateSeparator(_ separator: MessageDateSeparatorContext) -> some View {
        if let custom = presentation.slots.messageDateSeparator {
            Group(subviews: custom(separator)) { subviews in
                ForEach(subviews) { $0 }
            }
        } else {
            DateSeparator(separator: separator)
        }
    }

    @ViewBuilder
    private var messageRow: some View {
        if let customRow = presentation.slots.row(for: row.message, context: row.context) {
            customRow.modifier(longPress)
        } else {
            MessageRow(row: row, slots: presentation.slots, longPress: longPress)
        }
    }

    private var longPress: MessageLongPress {
        let signals = presentation.signals
        guard signals.overlay != nil else {
            return MessageLongPress(menu: signals.content(for: .longPress, message: row.message, isMine: row.isMine), overlay: nil)
        }
        let id = row.id
        return MessageLongPress(menu: nil, overlay: LongPressOverlayTarget(
            id: id,
            views: signals.overlayViews(for: row.message, isMine: row.isMine),
            isLifted: presentation.liftedMessageID == id,
            open: { [presentation] in presentation.signals.openOverlay(id) },
            onFrameChange: { [presentation] in presentation.onBubbleFrameChange($0, $1) }
        ))
    }
}

/// What a long press on the bubble shows: the host's overlay when it is declared, which replaces
/// the menu, or else the menu.
struct MessageLongPress: ViewModifier {
    let menu: AnyView?
    let overlay: LongPressOverlayTarget?

    func body(content: Content) -> some View {
        if let overlay {
            content.modifier(overlay)
        } else {
            content.modifier(LongPressMenu(menu: menu))
        }
    }
}

/// Offers the overlay on a bubble only when it has something to show, as the menu does: the
/// bubble's frame goes to the collection view's recognizer and VoiceOver gets "Show actions".
/// While lifted, the bubble is hidden but stays laid out, so it keeps reporting its frame.
struct LongPressOverlayTarget: ViewModifier {
    let id: String
    let views: AnyView?
    let isLifted: Bool
    let open: () -> Void
    let onFrameChange: (String, CGRect?) -> Void

    /// A reused cell keeps its geometry, so a new message with a bubble of the same size would
    /// never report a frame; the last one is sent again for the new id. Frames are not cleared on
    /// disappearing: a reconfigured cell's old content disappears after the new content reported,
    /// and the recognizer only reads frames of cells on screen.
    @State private var frame: CGRect?

    func body(content: Content) -> some View {
        if let views {
            Group(subviews: views) { items in
                if items.isEmpty {
                    content
                        .onAppear { onFrameChange(id, nil) }
                } else {
                    content
                        .opacity(isLifted ? 0 : 1)
                        .accessibilityAction(named: "Show actions", open)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(MessageListRow.cellSpace))
                        } action: { newFrame in
                            frame = newFrame
                            onFrameChange(id, newFrame)
                        }
                        .onAppear {
                            if let frame { onFrameChange(id, frame) }
                        }
                        .onChange(of: id) { oldID, newID in
                            onFrameChange(oldID, nil)
                            if let frame { onFrameChange(newID, frame) }
                        }
                }
            }
        } else {
            content
        }
    }
}

/// The signals below are attached around the default row and any slot alike, so a slot that
/// redraws the row cannot drop them. Buttons inside a slot still win.
///
/// A host closure is opaque until resolved, so each one is resolved before anything is attached:
/// an empty menu would still lift the row, and an empty dialog would hold only Cancel.
///
/// The menu lifts whatever it wraps, so `MessageRow` puts it on the bubble alone. Only a
/// whole-row slot, whose bubble the package cannot find, gets it around the row.
struct LongPressMenu: ViewModifier {
    let menu: AnyView?

    func body(content: Content) -> some View {
        if let menu {
            Group(subviews: menu) { items in
                if items.isEmpty {
                    content
                } else {
                    content.contextMenu { menu }
                }
            }
        } else {
            content
        }
    }
}

/// The swipe has no VoiceOver equivalent, so rows that can be answered carry a named action.
/// Every row is rebuilt when replying turns on or off (`MessageListContent.repliesEnabled`).
private struct ReplyAccessibilityAction: ViewModifier {
    let isAvailable: Bool
    let reply: () -> Void

    func body(content: Content) -> some View {
        if isAvailable {
            content.accessibilityAction(named: "Reply", reply)
        } else {
            content
        }
    }
}

/// Attached inside the failed-message tap, so that single tap waits for a double tap to fail
/// instead of firing first. Adds no content shape: widening the hit area here would also widen
/// the long-press menu's reach, only while a double tap is set.
private struct MessageDoubleTap: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(count: 2, perform: action)
        } else {
            content
        }
    }
}

/// Reports the tap so the screen shows `dialog` as a confirmation dialog; the dialog is not
/// placed in the cell, which reuse would lose.
private struct FailedMessageTap: ViewModifier {
    let message: ChatMessage
    let dialog: AnyView?
    let onSelect: (ChatMessage) -> Void

    func body(content: Content) -> some View {
        if let dialog {
            Group(subviews: dialog) { items in
                if items.isEmpty {
                    content
                } else {
                    content
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(message) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Shows what to do with the failed message")
                }
            }
        } else {
            content
        }
    }
}

struct MessageListTopStatus: View {
    let status: MessageListContent.TopStatus
    let presentation: MessageListCellPresentation

    private var theme: ChannelTheme { presentation.environment.channelTheme }

    @ViewBuilder
    var body: some View {
        switch status {
        case .loading:
            ProgressView()
                .tint(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        case .retry:
            Button("Tap to load more") { presentation.onRetry() }
                .font(theme.messageFont)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        case .none:
            EmptyView()
        }
    }
}
