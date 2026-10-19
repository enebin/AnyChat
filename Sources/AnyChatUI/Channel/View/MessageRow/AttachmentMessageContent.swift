import AnyChatCore
import SwiftUI

/// A message's attachments stacked above its body: media first, then files, then the text.
struct AttachmentMessageContent: View {
    let attachments: MessageRowState.Attachments
    let isMine: Bool
    let onSelect: ((ChatAttachment) -> Void)?
    let textBackground: AnyView?
    let showsTail: Bool
    let textLayout: ChannelSlots.MessageBubbleLayout

    /// The same gap as between bubbles of one run.
    private static let spacing: CGFloat = 8

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: Self.spacing) {
            if attachments.media.count == 1, let media = attachments.media.first {
                MediaAttachmentContent(attachment: media)
                    .attachmentTap(action(for: media))
            } else if attachments.media.count > 1 {
                MediaAttachmentGrid(attachments: attachments.media, isMine: isMine, onSelect: onSelect)
            }

            ForEach(attachments.files) { file in
                FileAttachmentContent(attachment: file, isMine: isMine)
                    .attachmentTap(action(for: file))
            }

            if let text = attachments.text {
                TextMessageContent(
                    text: text,
                    isMine: isMine,
                    background: textBackground,
                    showsTail: showsTail,
                    layout: textLayout
                )
            }
        }
    }

    private func action(for attachment: ChatAttachment) -> (() -> Void)? {
        onSelect.map { onSelect in { onSelect(attachment) } }
    }
}

extension View {
    /// Makes the view a button only when the host listens for attachment taps.
    @ViewBuilder
    func attachmentTap(_ action: (() -> Void)?) -> some View {
        if let action {
            Button(action: action) { self }
                .buttonStyle(.plain)
        } else {
            self
        }
    }
}
