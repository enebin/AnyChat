import SwiftUI

struct UnsupportedMessageContent: View {
    let isMine: Bool
    let background: AnyView?
    let showsTail: Bool
    let layout: ChannelSlots.MessageBubbleLayout

    static let text = "(Unknown message type)"

    var body: some View {
        TextMessageContent(text: Self.text, isMine: isMine, background: background, showsTail: showsTail, layout: layout)
    }
}
