import UIKit

final class MessageCollectionView: UICollectionView {
    var onLayout: (() -> Void)?

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
