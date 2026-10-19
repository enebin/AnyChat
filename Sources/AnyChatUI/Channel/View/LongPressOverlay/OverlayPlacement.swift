import CoreGraphics

/// Where the long-press overlay draws the lifted bubble, the host's view above it, and the card
/// below it, in the overlay's coordinate space.
///
/// The bubble is scaled from its top sender-side corner, and the gaps are measured from the
/// scaled frame. When the group does not fit in `bounds` it moves as a whole; when it still does
/// not fit, the bubble is cut first and then the card is shortened, which makes it scroll.
nonisolated struct OverlayPlacement: Equatable {
    static let liftScale: CGFloat = 1.12
    static let gap: CGFloat = 22
    static let sideInset: CGFloat = 16
    static let cardWidth: CGFloat = 249
    /// What stays of a cut bubble when the two views alone fill the screen, so the user still
    /// sees which message they act on.
    static let minimumBubbleHeight: CGFloat = 44

    /// The scaled bubble, uncut.
    let bubble: CGRect
    /// How much of `bubble`, from its top, is drawn.
    let visibleBubbleHeight: CGFloat
    let above: CGRect
    let card: CGRect

    /// - Parameters:
    ///   - bubble: The bubble's frame in the list, unscaled.
    ///   - aboveSize: The above view's size at `aboveProposalWidth(in:)`; zero when it is empty.
    ///   - cardSize: The card's ideal size; zero when it is empty.
    ///   - bounds: The space the group must stay in: from the top of the list to the keyboard's
    ///     top or the bottom safe area, between the safe area's sides.
    ///   - scalesBubble: `false` for a whole row drawn by a `messageRow` slot.
    init(bubble: CGRect, aboveSize: CGSize, cardSize: CGSize, bounds: CGRect, isMine: Bool, scalesBubble: Bool) {
        let scale = scalesBubble ? Self.liftScale : 1
        let scaledWidth = bubble.width * scale
        let scaledHeight = bubble.height * scale
        let scaledX = isMine ? bubble.maxX - scaledWidth : bubble.minX

        let aboveGap = aboveSize.height > 0 ? Self.gap : 0
        let cardGap = cardSize.height > 0 ? Self.gap : 0
        let fixedHeight = aboveSize.height + aboveGap + cardGap
        let roomForBubble = bounds.height - fixedHeight - cardSize.height
        let visibleHeight = min(scaledHeight, max(roomForBubble, Self.minimumBubbleHeight))
        let cardHeight = max(0, min(cardSize.height, bounds.height - fixedHeight - visibleHeight))

        let groupHeight = fixedHeight + visibleHeight + cardHeight
        let naturalTop = bubble.minY - aboveGap - aboveSize.height
        let top = max(bounds.minY, min(naturalTop, bounds.maxY - groupHeight))
        let bubbleY = top + aboveSize.height + aboveGap

        func x(forWidth width: CGFloat) -> CGFloat {
            let aligned = isMine ? scaledX + scaledWidth - width : scaledX
            let maxX = bounds.maxX - Self.sideInset - width
            return max(bounds.minX + Self.sideInset, min(aligned, maxX))
        }

        let aboveWidth = min(aboveSize.width, Self.aboveProposalWidth(in: bounds))
        self.bubble = CGRect(x: scaledX, y: bubbleY, width: scaledWidth, height: scaledHeight)
        visibleBubbleHeight = visibleHeight
        above = CGRect(x: x(forWidth: aboveWidth), y: top, width: aboveWidth, height: aboveSize.height)
        card = CGRect(x: x(forWidth: cardSize.width), y: bubbleY + visibleHeight + cardGap, width: cardSize.width, height: cardHeight)
    }

    /// The width the above view is offered: the transcript's width inside its side insets.
    static func aboveProposalWidth(in bounds: CGRect) -> CGFloat {
        max(0, bounds.width - sideInset * 2)
    }
}
