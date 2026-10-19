import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

struct MessageBubbleRow<Content: View>: View {
    let row: MessageRowState
    let avatar: AnyView?
    let senderName: AnyView?
    let time: AnyView?
    let quote: AnyView?
    let accessory: AnyView?
    let content: Content

    @Environment(\.channelTheme) private var theme

    static var avatarSize: CGFloat { 26 }
    private static var avatarSpacing: CGFloat { 12 }
    private static var accessorySpacing: CGFloat { 4 }
    /// The design source lifts the picture and the time 2pt off the bubble's bottom edge.
    private static var accessoryBottomInset: CGFloat { 2 }
    private static var senderNameInset: CGFloat { 12 }
    private static var receiptSize: CGFloat { 16 }

    init(
        row: MessageRowState,
        avatar: AnyView?,
        senderName: AnyView?,
        time: AnyView?,
        quote: AnyView?,
        accessory: AnyView?,
        @ViewBuilder content: () -> Content
    ) {
        self.row = row
        self.avatar = avatar
        self.senderName = senderName
        self.time = time
        self.quote = quote
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        if row.isMine {
            outgoing
        } else {
            incoming
        }
    }

    private var incoming: some View {
        HStack(alignment: .bubbleBottom, spacing: Self.avatarSpacing) {
            if let avatar { hostAvatar(avatar) }
            VStack(alignment: .leading, spacing: Self.accessorySpacing) {
                senderNameLine
                hostQuote
                HStack(alignment: .bottom, spacing: Self.accessorySpacing) {
                    content
                    hostTime
                }
                .alignmentGuide(.bubbleBottom) { $0[.bottom] }
                hostAccessory
            }
            Spacer(minLength: 0)
        }
    }

    private var outgoing: some View {
        HStack(alignment: .bubbleBottom, spacing: Self.accessorySpacing) {
            Spacer(minLength: 0)
            hostTime
            VStack(alignment: .trailing, spacing: Self.accessorySpacing) {
                hostQuote
                content
                    .alignmentGuide(.bubbleBottom) { $0[.bottom] }
                if let status = row.message.sendingStatus {
                    SendingStatusIndicator(status: status, size: Self.receiptSize)
                        .padding(.trailing, MessageBubbleShape.cornerRadius)
                } else if let receipt = row.receipt {
                    Text(receiptLabel(receipt))
                        .font(theme.timeFont)
                        .foregroundStyle(color(for: receipt))
                        .padding(.trailing, MessageBubbleShape.cornerRadius)
                }
                hostAccessory
            }
        }
    }

    /// Resolve empty host content before adding spacing beside the bubble.
    @ViewBuilder
    private var hostTime: some View {
        if let time {
            Group(subviews: time) { subviews in
                ForEach(subviews) { $0.padding(.bottom, row.isMine ? Self.accessoryBottomInset : 0) }
            }
        }
    }

    private func receiptLabel(_ receipt: ChatMessage.Receipt) -> String {
        switch receipt {
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .read: "Read"
        }
    }

    /// Resolved first so a closure that returns nothing removes the quote and its spacing.
    @ViewBuilder
    private var hostQuote: some View {
        if let quote {
            Group(subviews: quote) { subviews in
                ForEach(subviews) { $0 }
            }
        }
    }

    /// Resolved first so a closure that returns nothing adds no spacing below the bubble.
    @ViewBuilder
    private var hostAccessory: some View {
        if let accessory {
            Group(subviews: accessory) { subviews in
                ForEach(subviews) { $0 }
            }
        }
    }

    @ViewBuilder
    private var senderNameLine: some View {
        if let senderName {
            hostSenderName(senderName)
        } else if row.showsSenderName, let name = row.message.sender?.name {
            Text(name)
                .font(theme.senderNameFont)
                .foregroundStyle(theme.senderNameText)
                .padding(.leading, Self.senderNameInset)
        }
    }

    /// Resolved first so a closure that returns nothing removes the name and its spacing.
    private func hostSenderName(_ senderName: AnyView) -> some View {
        Group(subviews: senderName) { subviews in
            ForEach(subviews) { $0.padding(.leading, Self.senderNameInset) }
        }
    }

    /// Resolved first so a closure that returns nothing removes the column and its spacing. Hidden
    /// rather than left out on the other rows of a run, so the column keeps the host view's width.
    private func hostAvatar(_ avatar: AnyView) -> some View {
        Group(subviews: avatar) { subviews in
            if !subviews.isEmpty {
                ZStack {
                    ForEach(subviews) { $0 }
                }
                .opacity(row.showsAvatarSlot ? 1 : 0)
                .accessibilityHidden(!row.showsAvatarSlot)
                .padding(.bottom, Self.accessoryBottomInset)
            }
        }
    }

    private func color(for receipt: ChatMessage.Receipt) -> Color {
        switch receipt {
        case .sent: theme.receiptSent
        case .delivered: theme.receiptDelivered
        case .read: theme.receiptRead
        }
    }
}

private extension VerticalAlignment {
    /// Keeps host pictures and times aligned with the bubble when a receipt or accessory is below it.
    nonisolated enum BubbleBottom: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.bottom]
        }
    }

    nonisolated static let bubbleBottom = VerticalAlignment(BubbleBottom.self)
}
