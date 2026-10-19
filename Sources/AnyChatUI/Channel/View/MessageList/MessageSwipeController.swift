import UIKit

/// The collection view's one horizontal pan that starts a reply by dragging a row toward the
/// trailing edge.
///
/// A SwiftUI drag inside a hosted cell cannot be ordered against the list's scrolling or the back
/// swipe, so this recognizer decides at its first movement: a vertical drag fails it at once and
/// stays a scroll, and the back swipe from the screen edge goes first.
final class MessageSwipeController: NSObject, UIGestureRecognizerDelegate {
    static let threshold: CGFloat = 60
    private static let maxOffset: CGFloat = 90
    private static let resistance: CGFloat = 1.0 / 3.0
    private static let iconCircle: CGFloat = 32
    private static let iconPointSize: CGFloat = 15
    private static let iconInset: CGFloat = 16

    private let collectionView: UICollectionView
    private let dataSource: MessageListDataSource
    private let recognizer = UIPanGestureRecognizer()
    private let icon = UIImageView()
    private let iconBackground = UIView()
    private let haptics = UIImpactFeedbackGenerator(style: .light)

    var canReply: (String) -> Bool = { _ in false }
    var onReply: (String) -> Void = { _ in }

    private var swipingID: String?
    private var swipingCell: UICollectionViewCell?
    /// A picture of the row that moves in its place: a hosted cell redraws its content for its
    /// pressed state and drops a transform set on it, so the row would not follow the finger.
    private var swipingSnapshot: UIView?
    private var isPastThreshold = false

    var isSwiping: Bool {
        swipingCell != nil
    }

    init(collectionView: UICollectionView, dataSource: MessageListDataSource) {
        self.collectionView = collectionView
        self.dataSource = dataSource
        super.init()

        recognizer.addTarget(self, action: #selector(handlePan))
        recognizer.delegate = self
        collectionView.addGestureRecognizer(recognizer)
        // Vertical drags fail this recognizer at once, so scrolling and the interactive keyboard
        // dismissal start without a noticeable delay.
        collectionView.panGestureRecognizer.require(toFail: recognizer)

        iconBackground.frame.size = CGSize(width: Self.iconCircle, height: Self.iconCircle)
        iconBackground.layer.cornerRadius = Self.iconCircle / 2
        iconBackground.alpha = 0
        icon.image = UIImage(
            systemName: "arrowshape.turn.up.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Self.iconPointSize, weight: .semibold)
        )
        icon.contentMode = .center
        icon.frame = iconBackground.bounds
        iconBackground.addSubview(icon)
        iconBackground.isUserInteractionEnabled = false
        collectionView.addSubview(iconBackground)
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func setColors(icon iconColor: UIColor, background: UIColor) {
        icon.tintColor = iconColor
        iconBackground.backgroundColor = background
    }

    /// The back swipe from the screen edge keeps priority over a row's swipe.
    func yield(to backSwipe: UIGestureRecognizer?) {
        if let backSwipe {
            recognizer.require(toFail: backSwipe)
        }
    }

    /// How far the row's content moves for the finger's travel toward the trailing edge: one to
    /// one up to the threshold, then a third of the extra travel, up to `maxOffset`.
    static func offset(forTravel travel: CGFloat) -> CGFloat {
        guard travel > threshold else {
            return max(0, travel)
        }
        return min(maxOffset, threshold + (travel - threshold) * resistance)
    }

    static func isPastThreshold(travel: CGFloat) -> Bool {
        offset(forTravel: travel) >= threshold
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let velocity = recognizer.velocity(in: collectionView)
        let towardTrailing = trailingSign * velocity.x
        guard towardTrailing > 0, abs(velocity.x) > abs(velocity.y) * 2 else {
            return false
        }
        let location = recognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              let id = dataSource.rowID(at: indexPath),
              !touchBelongsToSlot(at: location) else {
            return false
        }
        return canReply(id)
    }

    /// A slot's own controls go first ("슬롯과 동작"): a drag that starts on a control or inside a
    /// scroll view the slot can move sideways stays with the slot.
    private func touchBelongsToSlot(at location: CGPoint) -> Bool {
        var view = collectionView.hitTest(location, with: nil)
        while let current = view, current !== collectionView {
            if current is UIControl {
                return true
            }
            if let scrollView = current as? UIScrollView, scrollView.contentSize.width > scrollView.bounds.width {
                return true
            }
            view = current.superview
        }
        return false
    }

    // MARK: - Pan

    @objc private func handlePan() {
        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: location),
                  let cell = collectionView.cellForItem(at: indexPath) else {
                return
            }
            // A spring-back still running would otherwise finish on top of the new swipe.
            let wasHidden = cell.contentView.alpha == 0
            finishSpringBack()
            iconBackground.layer.removeAllAnimations()
            // The last render of a row that was springing back is blank, so draw it again.
            guard let snapshot = cell.snapshotView(afterScreenUpdates: wasHidden) else {
                return
            }
            snapshot.frame = cell.frame
            collectionView.addSubview(snapshot)
            cell.contentView.alpha = 0
            swipingID = dataSource.rowID(at: indexPath)
            swipingCell = cell
            swipingSnapshot = snapshot
            isPastThreshold = false
            haptics.prepare()
            placeIcon(beside: cell, below: snapshot)
        case .changed:
            guard swipingCell != nil else { return }
            update(travel: trailingSign * recognizer.translation(in: collectionView).x)
        case .ended:
            if isPastThreshold, let swipingID {
                onReply(swipingID)
            }
            springBack()
        case .cancelled, .failed:
            springBack()
        case .possible, .recognized:
            break
        @unknown default:
            break
        }
    }

    private func update(travel: CGFloat) {
        let offset = Self.offset(forTravel: travel)
        swipingSnapshot?.transform = CGAffineTransform(translationX: trailingSign * offset, y: 0)

        let progress = min(1, offset / Self.threshold)
        iconBackground.alpha = progress
        let scale = 0.5 + 0.5 * progress
        iconBackground.transform = CGAffineTransform(scaleX: scale, y: scale)

        let pastThreshold = Self.isPastThreshold(travel: travel)
        if pastThreshold, !isPastThreshold {
            haptics.impactOccurred()
        }
        isPastThreshold = pastThreshold
    }

    private func placeIcon(beside cell: UICollectionViewCell, below snapshot: UIView) {
        let frame = cell.frame
        let x = trailingSign > 0
            ? frame.minX + Self.iconInset + Self.iconCircle / 2
            : frame.maxX - Self.iconInset - Self.iconCircle / 2
        iconBackground.transform = .identity
        iconBackground.center = CGPoint(x: x, y: frame.midY)
        iconBackground.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        iconBackground.alpha = 0
        collectionView.insertSubview(iconBackground, belowSubview: snapshot)
    }

    /// Ends a swipe at once, without a reply: the list is about to move or reuse the row under
    /// the picture.
    func cancel() {
        guard swipingCell != nil || springingBack != nil else { return }
        if swipingCell != nil {
            springingBack = (swipingCell, swipingSnapshot)
            swipingCell = nil
            swipingSnapshot = nil
            swipingID = nil
            isPastThreshold = false
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
        iconBackground.layer.removeAllAnimations()
        iconBackground.alpha = 0
        finishSpringBack()
    }

    private func springBack() {
        guard swipingCell != nil else { return }
        let cell = swipingCell
        let snapshot = swipingSnapshot
        swipingCell = nil
        swipingSnapshot = nil
        swipingID = nil
        isPastThreshold = false
        springingBack = (cell, snapshot)
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            snapshot?.transform = .identity
            self.iconBackground.alpha = 0
            self.iconBackground.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        } completion: { _ in
            if self.springingBack?.snapshot === snapshot {
                self.finishSpringBack()
            }
        }
    }

    private var springingBack: (cell: UICollectionViewCell?, snapshot: UIView?)?

    /// Puts the real row back in place of its picture.
    private func finishSpringBack() {
        guard let springingBack else { return }
        self.springingBack = nil
        springingBack.snapshot?.removeFromSuperview()
        springingBack.cell?.contentView.alpha = 1
    }

    /// The trailing edge is on the right in left-to-right layouts and on the left otherwise.
    private var trailingSign: CGFloat {
        collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? -1 : 1
    }
}
