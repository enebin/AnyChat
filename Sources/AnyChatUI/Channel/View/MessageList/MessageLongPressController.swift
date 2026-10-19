import UIKit

/// The collection view's long press that opens the host's overlay around a message's bubble.
///
/// A SwiftUI gesture inside a hosted cell cannot cancel a button's touch under it or the list's
/// pan, so this recognizer sits on the collection view next to the reply swipe. It fires only
/// inside a bubble that a cell registered, which cells do only when the overlay has something to
/// show for their message.
final class MessageLongPressController: NSObject, UIGestureRecognizerDelegate {
    /// The system context menu's.
    static let minimumPressDuration: TimeInterval = 0.5

    private let collectionView: UICollectionView
    private let dataSource: MessageListDataSource
    private let swipeController: MessageSwipeController?
    private let recognizer = UILongPressGestureRecognizer()
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    /// Each bubble's frame in its cell's content view, so a cell that moves never leaves a stale
    /// frame behind.
    private var bubbleFrames: [String: CGRect] = [:]
    /// Recognizers inside the cells that track the same touch, such as a SwiftUI button's.
    private var cellRecognizers: [UIGestureRecognizer] = []

    var onOpen: (String) -> Void = { _ in }

    init(collectionView: UICollectionView, dataSource: MessageListDataSource, swipeController: MessageSwipeController?) {
        self.collectionView = collectionView
        self.dataSource = dataSource
        self.swipeController = swipeController
        super.init()

        recognizer.minimumPressDuration = Self.minimumPressDuration
        recognizer.addTarget(self, action: #selector(handlePress))
        recognizer.delegate = self
        collectionView.addGestureRecognizer(recognizer)
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func detach() {
        collectionView.removeGestureRecognizer(recognizer)
    }

    func setBubbleFrame(_ frame: CGRect?, for id: String) {
        bubbleFrames[id] = frame
    }

    /// The bubble's current frame in `view`, or `nil` while its cell is off the screen.
    func bubbleFrame(for id: String, in view: UIView) -> CGRect? {
        guard let local = bubbleFrames[id],
              let indexPath = dataSource.indexPath(for: id),
              let cell = collectionView.cellForItem(at: indexPath) else {
            return nil
        }
        let inList = cell.contentView.convert(local, to: collectionView)
        guard inList.intersects(collectionView.bounds) else {
            return nil
        }
        return cell.contentView.convert(local, to: view)
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !collectionView.isDragging, !collectionView.isDecelerating, swipeController?.isSwiping != true else {
            return false
        }
        return messageID(at: recognizer.location(in: collectionView)) != nil
    }

    /// A button inside the bubble starts tracking at touch down, which would keep this recognizer
    /// from ever recognizing; they run together until the press is long enough, and then the
    /// button's touch is cancelled.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        guard let view = other.view, view !== collectionView, view.isDescendant(of: collectionView) else {
            return false
        }
        if !cellRecognizers.contains(where: { $0 === other }) {
            cellRecognizers.append(other)
        }
        return true
    }

    private func messageID(at location: CGPoint) -> String? {
        guard let indexPath = collectionView.indexPathForItem(at: location),
              let id = dataSource.rowID(at: indexPath),
              let local = bubbleFrames[id],
              let cell = collectionView.cellForItem(at: indexPath),
              cell.contentView.convert(local, to: collectionView).contains(location) else {
            return nil
        }
        return id
    }

    // MARK: - Press

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        cellRecognizers.removeAll()
        return true
    }

    @objc private func handlePress() {
        guard recognizer.state == .began, let id = messageID(at: recognizer.location(in: collectionView)) else {
            return
        }
        for other in cellRecognizers {
            other.isEnabled = false
            other.isEnabled = true
        }
        cellRecognizers.removeAll()
        swipeController?.cancel()
        // Recognizing already keeps the pan from starting; toggling it also stops a pan that was
        // waiting on the swipe, so the rest of this touch cannot scroll under the overlay.
        collectionView.panGestureRecognizer.isEnabled = false
        collectionView.panGestureRecognizer.isEnabled = true
        haptics.impactOccurred()
        onOpen(id)
    }
}
