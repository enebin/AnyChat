import AnyChatCore
import SwiftUI

struct MessageRow: View {
    let row: MessageRowState
    let slots: ChannelSlots
    let longPress: MessageLongPress

    var body: some View {
        switch row.content {
        case let .system(text):
            SystemMessageRow(text: text)
                .modifier(longPress)
        case .text, .attachments, .placeholder:
            bubbleRow
        }
    }

    private var bubbleRow: some View {
        MessageBubbleRow(
            row: row,
            avatar: slots.messageAvatar?(row.message, row.context),
            senderName: row.showsSenderNameSlot ? slots.messageSenderName?(row.message, row.context) : nil,
            time: row.timeText != nil ? slots.messageTime?(row.message, row.context) : nil,
            quote: quote,
            accessory: slots.messageAccessory?(row.message, row.context)
        ) {
            MessageBubbleContent(row: row, slots: slots)
                .modifier(longPress)
        }
    }

    private var quote: AnyView? {
        guard let replyQuote = row.replyQuote else {
            return nil
        }
        return slots.messageReplyQuote?(row.message, row.context)
            ?? AnyView(MessageReplyQuote(quote: replyQuote, isMine: row.isMine))
    }
}

/// The bubble alone: the `messageContent` slot's view or the default content. The long press
/// lifts this, and the long-press overlay draws it again.
struct MessageBubbleContent: View {
    let row: MessageRowState
    let slots: ChannelSlots

    var body: some View {
        if let customContent = slots.content(for: row.message, context: row.context) {
            customContent
        } else {
            defaultContent
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        let showsTail = row.groupPosition == .single || row.groupPosition == .last
        switch row.content {
        case let .text(text):
            TextMessageContent(
                text: text,
                isMine: row.isMine,
                background: bubbleBackground,
                showsTail: showsTail,
                layout: slots.messageBubbleLayout
            )
        case let .attachments(attachments):
            AttachmentMessageContent(
                attachments: attachments,
                isMine: row.isMine,
                onSelect: onAttachmentSelected,
                textBackground: bubbleBackground,
                showsTail: showsTail,
                textLayout: slots.messageBubbleLayout
            )
        case .placeholder:
            UnsupportedMessageContent(
                isMine: row.isMine,
                background: bubbleBackground,
                showsTail: showsTail,
                layout: slots.messageBubbleLayout
            )
        case let .system(text):
            SystemMessageRow(text: text)
        }
    }

    private var bubbleBackground: AnyView? {
        slots.messageBubbleBackground?(row.message, row.context)
    }

    /// An unsent file is not on the backend yet, and an attachment button would take the tap that
    /// opens Retry / Remove.
    private var onAttachmentSelected: ((ChatAttachment) -> Void)? {
        guard row.message.sendingStatus == nil else {
            return nil
        }
        return slots.attachmentSelected.map { action in { action($0, row.message) } }
    }
}
