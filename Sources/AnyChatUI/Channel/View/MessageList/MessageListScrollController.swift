import UIKit

final class MessageListScrollController {
    private static let maxSettlePasses = 4
    private static let offsetTolerance: CGFloat = 0.5

    private let collectionView: UICollectionView
    private let dataSource: MessageListDataSource
    private var anchor: ScrollAnchor = .bottom
    private var isPinnedToBottom = true
    private(set) var isUpdating = false
    private var isRestoring = false
    private var isAnimatingToBottom = false
    private var isAwayFromBottom = false
    var onAwayFromBottomChange: (Bool) -> Void = { _ in }
    var scrollBehavior = MessageScrollBehavior.followsLatest
    private(set) var awaitsSentRow = false
    /// The sent row that the space below the content lets reach the top, while it needs space.
    private var sentRowID: String?

    init(collectionView: UICollectionView, dataSource: MessageListDataSource) {
        self.collectionView = collectionView
        self.dataSource = dataSource
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    var distanceToTop: CGFloat { geometry.distanceToTop }
    var viewportHeight: CGFloat { geometry.viewportHeight }
    var isAdjusting: Bool { isUpdating || isRestoring }

    func beginUpdate(changedRowIDs: Set<String>) {
        anchor = dataSource.isEmpty ? .bottom : capture(excluding: changedRowIDs)
        isUpdating = true
        // Setting the offset directly does not stop an animated scroll, which would carry on toward
        // the old bottom after the settle below.
        if isAnimatingToBottom {
            collectionView.setContentOffset(collectionView.contentOffset, animated: false)
            isAnimatingToBottom = false
        }
        // An existing overscroll bounce must not keep moving a newly prepended page.
        if collectionView.contentOffset.y < geometry.minOffset {
            collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        }
    }

    /// - Parameter sentRowID: the row a send added, found while `awaitsSentRow`.
    func endUpdate(sentRowID: String?) {
        if let sentRowID {
            moveToTop(sentRowID)
        }
        settle()
        isUpdating = false
        reportAwayFromBottom()
    }

    func didLayout() {
        defer { reportAwayFromBottom() }
        // The space depends on the content and the insets, not the offset, so a drag does not stop it.
        if !isAdjusting, viewportHeight > 0 {
            updateSpaceBelowContent()
        }
        // Restoring the anchor mid-animation would stop the scroll to the bottom.
        guard !isUpdating, !isRestoring, !isAnimatingToBottom, viewportHeight > 0,
              !collectionView.isTracking, !collectionView.isDecelerating else {
            return
        }
        settle()
    }

    func didScroll() {
        reportAwayFromBottom()
        guard !isUpdating, !isRestoring,
              collectionView.isTracking || collectionView.isDecelerating else {
            return
        }
        anchor = capture()
    }

    /// Returns to the newest message and follows new ones, as after the user sends.
    func pinToBottom() {
        // A fling still running would carry on from the restored offset and leave the bottom.
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        isAnimatingToBottom = false
        isPinnedToBottom = true
        anchor = .bottom
        settle()
        reportAwayFromBottom()
    }

    /// Pins to the bottom for a send. With `questionToTop`, the sent row then moves to the top when
    /// it arrives.
    func didSend() {
        // Pinning onto the previous question's space would show a blank screen.
        sentRowID = nil
        setSpaceBelowContent(0)
        pinToBottom()
        awaitsSentRow = scrollBehavior == .questionToTop
    }

    /// Like `pinToBottom()`, but scrolls there with an animation.
    func scrollToBottomAnimated() {
        let target = geometry.maxOffset
        guard abs(collectionView.contentOffset.y - target) > Self.offsetTolerance else {
            pinToBottom()
            return
        }
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        isPinnedToBottom = true
        anchor = .bottom
        isAnimatingToBottom = true
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: target), animated: true)
    }

    func didEndScrollingAnimation() {
        guard isAnimatingToBottom else { return }
        isAnimatingToBottom = false
        // Rows measured on the way can move the bottom away from where the animation ended.
        settle()
        reportAwayFromBottom()
    }

    func willBeginDragging() {
        isAnimatingToBottom = false
        awaitsSentRow = false
        isPinnedToBottom = false
        anchor = capture()
    }

    func didEndDragging(willDecelerate: Bool) {
        if !willDecelerate {
            finishScrolling()
        }
    }

    func didEndDecelerating() {
        finishScrolling()
    }

    private func finishScrolling() {
        isPinnedToBottom = geometry.isAtBottom
        anchor = capture()
    }

    private func moveToTop(_ id: String) {
        awaitsSentRow = false
        isPinnedToBottom = false
        sentRowID = id
        anchor = ScrollAnchor.sentRowAtTop(id: id, in: geometry)
    }

    private func updateSpaceBelowContent() {
        guard let sentRowID else { return }
        var withoutSpace = geometry
        withoutSpace.bottomInset -= collectionView.contentInset.bottom
        let space = dataSource.frame(for: sentRowID, in: collectionView).map {
            ScrollAnchor.spaceBelowContent(bringingRowAt: $0.minY, toTopOf: withoutSpace)
        } ?? 0
        if space == 0 {
            self.sentRowID = nil
        }
        setSpaceBelowContent(space)
    }

    private func setSpaceBelowContent(_ space: CGFloat) {
        let current = collectionView.contentInset.bottom
        guard space == 0 ? current != 0 : abs(current - space) > Self.offsetTolerance else { return }
        collectionView.contentInset.bottom = space
    }

    private func reportAwayFromBottom() {
        guard !isAdjusting, viewportHeight > 0 else { return }
        let isAway = geometry.isAwayFromBottom
        guard isAway != isAwayFromBottom else { return }
        isAwayFromBottom = isAway
        onAwayFromBottomChange(isAway)
    }

    private func capture(excluding changedRowIDs: Set<String> = []) -> ScrollAnchor {
        let visibleRows = dataSource.visibleRows(in: collectionView)
            .filter { $0.frame.maxY > geometry.visibleTop }
        // A changed row may gain spacing or lose its date pill within its own frame.
        let row = visibleRows.first { !changedRowIDs.contains($0.id) } ?? visibleRows.first
        return ScrollAnchor.capture(
            geometry,
            isPinnedToBottom: isPinnedToBottom,
            firstVisibleRow: row.map { (id: $0.id, minY: $0.frame.minY) }
        )
    }

    private func settle() {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        // Restoring an offset can expose cells whose estimated heights need another layout pass.
        for _ in 0..<Self.maxSettlePasses {
            collectionView.layoutIfNeeded()
            updateSpaceBelowContent()
            let rowMinY: CGFloat?
            if case let .row(id, _) = anchor {
                rowMinY = dataSource.frame(for: id, in: collectionView)?.minY
            } else {
                rowMinY = nil
            }
            let offset = anchor.restoredOffset(in: geometry, rowMinY: rowMinY)
            guard abs(collectionView.contentOffset.y - offset) > Self.offsetTolerance else {
                break
            }
            collectionView.contentOffset.y = offset
        }

        if case let .row(id, _) = anchor, dataSource.frame(for: id, in: collectionView) == nil {
            anchor = capture()
        }
    }

    private var geometry: ScrollAnchor.Geometry {
        ScrollAnchor.Geometry(
            offset: collectionView.contentOffset.y,
            viewportHeight: collectionView.bounds.height,
            contentHeight: collectionView.contentSize.height,
            topInset: collectionView.adjustedContentInset.top,
            bottomInset: collectionView.adjustedContentInset.bottom
        )
    }
}
