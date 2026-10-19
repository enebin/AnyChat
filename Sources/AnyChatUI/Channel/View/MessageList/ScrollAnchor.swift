import CoreGraphics

/// Where the message list should stay while its content changes underneath.
///
/// Pinned to the bottom, the list follows new and growing messages. Anywhere else, one visible row
/// keeps its place on screen, so rows added above or below do not move what is being read.
nonisolated enum ScrollAnchor: Equatable {
    case bottom
    case row(id: String, distanceFromViewportTop: CGFloat)

    /// Within this distance of the end, the list counts as being at the bottom.
    static let bottomTolerance: CGFloat = 8
    /// Beyond this distance from the end, the jump-to-latest button shows. About two one-line
    /// bubbles, so a nudge or a bounce at the bottom does not flash it.
    static let awayFromBottomDistance: CGFloat = 100
    /// How far below the visible top a sent row lands with `questionToTop`: the list's own top
    /// inset, so it sits where the first row does.
    static let sentRowTopSpacing: CGFloat = 16

    /// The vertical extent of a scroll view, in content coordinates.
    struct Geometry: Equatable {
        var offset: CGFloat
        var viewportHeight: CGFloat
        var contentHeight: CGFloat
        var topInset: CGFloat
        var bottomInset: CGFloat

        var minOffset: CGFloat { -topInset }
        var maxOffset: CGFloat { max(minOffset, contentHeight + bottomInset - viewportHeight) }
        var visibleTop: CGFloat { offset + topInset }
        var distanceToTop: CGFloat { offset - minOffset }

        var isAtBottom: Bool {
            maxOffset - offset <= ScrollAnchor.bottomTolerance
        }

        var isAwayFromBottom: Bool {
            maxOffset - offset > ScrollAnchor.awayFromBottomDistance
        }

        func clamped(_ offset: CGFloat) -> CGFloat {
            min(max(offset, minOffset), maxOffset)
        }
    }

    /// - Parameter firstVisibleRow: the topmost row whose bottom edge is below the visible top.
    static func capture(
        _ geometry: Geometry,
        isPinnedToBottom: Bool,
        firstVisibleRow: (id: String, minY: CGFloat)?
    ) -> ScrollAnchor {
        guard !isPinnedToBottom, let firstVisibleRow else {
            return .bottom
        }
        return .row(id: firstVisibleRow.id, distanceFromViewportTop: firstVisibleRow.minY - geometry.offset)
    }

    static func sentRowAtTop(id: String, in geometry: Geometry) -> ScrollAnchor {
        .row(id: id, distanceFromViewportTop: geometry.topInset + sentRowTopSpacing)
    }

    /// The space to add below the content so the row starting at `rowMinY` can scroll up to where
    /// `sentRowAtTop(id:in:)` puts it. It shrinks as content grows below the row and is 0 once that
    /// content reaches the visible bottom.
    ///
    /// - Parameter geometry: the list without the space, which must not count toward its own size.
    static func spaceBelowContent(bringingRowAt rowMinY: CGFloat, toTopOf geometry: Geometry) -> CGFloat {
        let rowAtTopOffset = rowMinY - sentRowTopSpacing - geometry.topInset
        let furthestOffset = geometry.contentHeight + geometry.bottomInset - geometry.viewportHeight
        return max(0, rowAtTopOffset - furthestOffset)
    }

    /// The offset that puts the anchor back where it was.
    ///
    /// - Parameter rowMinY: where the anchored row now starts, or `nil` when it is gone.
    func restoredOffset(in geometry: Geometry, rowMinY: CGFloat?) -> CGFloat {
        switch self {
        case .bottom:
            return geometry.maxOffset
        case let .row(_, distance):
            guard let rowMinY else {
                return geometry.clamped(geometry.offset)
            }
            return geometry.clamped(rowMinY - distance)
        }
    }
}
