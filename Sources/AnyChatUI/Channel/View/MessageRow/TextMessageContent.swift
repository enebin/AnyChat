import SwiftUI

struct TextMessageContent: View {
    let text: String
    let isMine: Bool
    /// A host's background drawn in place of the default rounded fill.
    let background: AnyView?
    let showsTail: Bool
    let layout: ChannelSlots.MessageBubbleLayout

    @Environment(\.channelTheme) private var theme

    private static let defaultMaxWidth: CGFloat = 240
    private static let defaultInsets = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
    private static let bodyLineHeight: CGFloat = 22
    private static let bodyLineSpacing: CGFloat = bodyLineHeight - UIFont.systemFont(ofSize: 17).lineHeight

    var body: some View {
        let insets = layout.insets ?? Self.defaultInsets
        BubbleWidthLimit(maxWidth: layout.maxWidth ?? Self.defaultMaxWidth) {
            Text(text)
                .font(theme.messageFont)
                .foregroundStyle(isMine ? theme.outgoingMessageText : theme.incomingMessageText)
                .lineSpacing(Self.bodyLineSpacing)
                .padding(insets)
                .frame(minHeight: Self.bodyLineHeight + insets.top + insets.bottom)
                .padding(.bottom, background == nil && showsTail ? MessageBubbleShape.tailHeight : 0)
                .background { bubbleBackground }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if let background {
            background
        } else {
            MessageBubbleShape(isMine: isMine, showsTail: showsTail)
                .fill(isMine ? theme.outgoingBubbleBackground : theme.incomingBubbleBackground)
        }
    }
}
