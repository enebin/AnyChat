import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// The host's views around a long-pressed message, drawn over `ChannelBody`.
///
/// It draws the bubble again from the current row, over its cell, which hides its own, and dims
/// the list and the composer around it. Everything is read again on every update: the row, the
/// context, and the bubble's frame, so the copy follows its cell.
struct MessageLongPressOverlay: View {
    let row: MessageRowState
    /// The cell's bubble in this view's coordinate space.
    let bubbleFrame: CGRect
    let slots: ChannelSlots
    let signals: MessageSignals
    let views: ChannelSlots.MessageOverlayViews
    /// The part of the top safe area that belongs to the list rather than the navigation bar,
    /// such as the default header's name capsule, which the dim covers.
    let listTopInset: CGFloat
    /// Removes the overlay at once.
    let onDismiss: () -> Void

    @Environment(\.channelTheme) private var theme
    @State private var isLifted = false
    @State private var isClosing = false
    @AccessibilityFocusState private var focus: Focus?

    private enum Focus {
        case above
        case card
    }

    /// The overlay stays open only while its message is in the list and is not a system message.
    static func presentableRow(id: String, in rows: [MessageRowState]) -> MessageRowState? {
        guard let row = rows.first(where: { $0.id == id }), !row.message.content.isSystem else {
            return nil
        }
        return row
    }

    var body: some View {
        let context = signals.overlayContext(for: row.message, isMine: row.isMine, dismiss: close)
        Group(subviews: views.above(row.message, context)) { aboveItems in
            // Resolved subviews keep the environment they were declared in, so the row style goes
            // on the closure's result; a host button's own style is closer and still wins.
            Group(subviews: views.below(row.message, context).buttonStyle(OverlayRowButtonStyle(theme: theme))) { belowItems in
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        dim(safeAreaTop: proxy.safeAreaInsets.top)
                        OverlayLayout(
                            bubbleFrame: bubbleFrame,
                            safeArea: proxy.safeAreaInsets,
                            isMine: row.isMine,
                            scalesBubble: scalesBubble,
                            isLifted: isLifted
                        ) {
                            liftedBubble
                                .layoutValue(key: OverlayPart.self, value: .bubble)
                            if !aboveItems.isEmpty {
                                above(aboveItems)
                                    .layoutValue(key: OverlayPart.self, value: .above)
                            }
                            if !belowItems.isEmpty {
                                card(belowItems)
                                    .layoutValue(key: OverlayPart.self, value: .card)
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
                .onAppear {
                    focus = aboveItems.isEmpty ? .card : .above
                }
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
        .onAppear {
            withAnimation { isLifted = true }
        }
    }

    /// Reverses the lift toward the bubble's current frame, then removes the overlay.
    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation {
            isLifted = false
        } completion: {
            onDismiss()
        }
    }

    /// A whole row drawn by a `messageRow` slot is lifted unscaled.
    private var customRow: AnyView? {
        slots.row(for: row.message, context: row.context)
    }

    private var scalesBubble: Bool {
        customRow == nil
    }

    // MARK: - Parts

    /// Leaves the navigation bar undimmed and reaches the screen's bottom edge behind the
    /// composer and the home indicator.
    private func dim(safeAreaTop: CGFloat) -> some View {
        theme.overlayDim
            .padding(.top, max(0, safeAreaTop - listTopInset))
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
            .accessibilityElement()
            .accessibilityLabel("Dismiss")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, close)
            .opacity(isLifted ? 1 : 0)
    }

    private var liftedBubble: some View {
        CutBubble(fullHeight: bubbleFrame.height) {
            Group {
                if let customRow {
                    customRow
                } else {
                    MessageBubbleContent(row: row, slots: slots)
                }
            }
            .frame(width: bubbleFrame.width, height: bubbleFrame.height, alignment: .top)
        }
        .scaleEffect(isLifted && scalesBubble ? OverlayPlacement.liftScale : 1, anchor: senderTopCorner)
        .allowsHitTesting(false)
    }

    private func above(_ items: SubviewsCollection) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { $0 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityFocused($focus, equals: .above)
        .opacity(isLifted ? 1 : 0)
        .scaleEffect(isLifted ? 1 : 0.8, anchor: row.isMine ? .bottomTrailing : .bottomLeading)
    }

    /// Its ideal height is its rows'; offered less, it scrolls.
    private func card(_ items: SubviewsCollection) -> some View {
        let rows = VStack(spacing: 0) {
            ForEach(items) { $0 }
        }
        return ViewThatFits(in: .vertical) {
            rows
            ScrollView { rows }
        }
        .frame(width: OverlayPlacement.cardWidth)
        .modifier(GlassSurface(tint: theme.background, shape: Self.cardShape))
        .clipShape(Self.cardShape)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($focus, equals: .card)
        .opacity(isLifted ? 1 : 0)
        .scaleEffect(isLifted ? 1 : 0.8, anchor: senderTopCorner)
    }

    private var senderTopCorner: UnitPoint {
        row.isMine ? .topTrailing : .topLeading
    }

    private static let cardShape = RoundedRectangle(cornerRadius: 34)
}

/// The card's rows: the design source's 52pt row with the label at the leading edge.
struct OverlayRowButtonStyle: ButtonStyle {
    static let rowHeight: CGFloat = 52
    private static let horizontalPadding: CGFloat = 16

    let theme: ChannelTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.messageFont)
            .foregroundStyle(configuration.role == .destructive ? theme.failedIndicatorTint : theme.composerText)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .padding(.horizontal, Self.horizontalPadding)
            .background(configuration.isPressed ? theme.replyBarCloseBackground : .clear)
            .contentShape(Rectangle())
    }
}

private nonisolated enum OverlayPart: LayoutValueKey {
    static let defaultValue = Part.bubble

    enum Part {
        case bubble
        case above
        case card
    }
}

/// Places the three parts from `OverlayPlacement` in one pass, from the sizes the views take.
/// Before the lift and while it reverses, the bubble sits on its cell's bubble.
private struct OverlayLayout: Layout {
    let bubbleFrame: CGRect
    let safeArea: EdgeInsets
    let isMine: Bool
    let scalesBubble: Bool
    let isLifted: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let area = CGRect(
            x: safeArea.leading,
            y: safeArea.top,
            width: bounds.width - safeArea.leading - safeArea.trailing,
            height: bounds.height - safeArea.top - safeArea.bottom
        )
        let bubble = subviews.first { $0[OverlayPart.self] == .bubble }
        let above = subviews.first { $0[OverlayPart.self] == .above }
        let card = subviews.first { $0[OverlayPart.self] == .card }
        let aboveSize = above?.sizeThatFits(ProposedViewSize(width: OverlayPlacement.aboveProposalWidth(in: area), height: nil)) ?? .zero
        let cardSize = card?.sizeThatFits(ProposedViewSize(width: OverlayPlacement.cardWidth, height: nil)) ?? .zero
        let placement = OverlayPlacement(
            bubble: bubbleFrame,
            aboveSize: aboveSize,
            cardSize: cardSize,
            bounds: area,
            isMine: isMine,
            scalesBubble: scalesBubble
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: bounds.minX + x, y: bounds.minY + y)
        }

        if isLifted {
            let scale = placement.bubble.width / max(bubbleFrame.width, 1)
            // The bubble is drawn unscaled and scaled from its top sender-side corner.
            let x = isMine ? placement.bubble.maxX - bubbleFrame.width : placement.bubble.minX
            bubble?.place(
                at: point(x, placement.bubble.minY),
                proposal: ProposedViewSize(width: bubbleFrame.width, height: placement.visibleBubbleHeight / scale)
            )
        } else {
            bubble?.place(at: point(bubbleFrame.minX, bubbleFrame.minY), proposal: ProposedViewSize(bubbleFrame.size))
        }
        above?.place(at: point(placement.above.minX, placement.above.minY), proposal: ProposedViewSize(placement.above.size))
        card?.place(at: point(placement.card.minX, placement.card.minY), proposal: ProposedViewSize(placement.card.size))
    }
}

/// Shows the bubble down to the height it is offered and fades its bottom edge when that cuts it.
private struct CutBubble<Content: View>: View {
    let fullHeight: CGFloat
    @ViewBuilder let content: Content

    private static var fadeHeight: CGFloat { 32 }

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(height: proxy.size.height, alignment: .top)
                .clipped()
                .mask {
                    if proxy.size.height < fullHeight - 0.5 {
                        VStack(spacing: 0) {
                            Rectangle()
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: Self.fadeHeight)
                        }
                    } else {
                        Rectangle()
                    }
                }
        }
    }
}
