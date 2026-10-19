import SwiftUI
import UIKit

final class MessageListDataSource {
    private nonisolated enum Item: Hashable, Sendable {
        case topStatus
        case row(String)
    }

    private struct Entry: Equatable {
        let row: MessageRowState
        let isFirst: Bool
    }

    private var source: UICollectionViewDiffableDataSource<Int, Item>?
    private var entries: [String: Entry] = [:]
    private(set) var content = MessageListContent()
    private let presentation: MessageListCellPresentation

    var isEmpty: Bool { content.rows.isEmpty }
    var firstRowID: String? { content.rows.first?.id }

    init(collectionView: UICollectionView, presentation: MessageListCellPresentation) {
        self.presentation = presentation
        let rowCell = UICollectionView.CellRegistration<UICollectionViewCell, String> { [weak self] cell, _, id in
            guard let self, let entry = entries[id] else { return }
            cell.contentConfiguration = UIHostingConfiguration {
                MessageListRow(row: entry.row, isFirst: entry.isFirst, presentation: presentation)
                    .id(entry.row.id)
                    // A reconfigured row is drawn at the cell's old height before the cell resizes,
                    // which squeezed wrapping text in a growing row down to one truncated line.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .margins(.all, 0)
        }
        let statusCell = UICollectionView.CellRegistration<UICollectionViewCell, Void> { [weak self] cell, _, _ in
            guard let self else { return }
            let status = content.topStatus
            cell.contentConfiguration = UIHostingConfiguration {
                MessageListTopStatus(status: status, presentation: presentation)
            }
            .margins(.all, 0)
        }
        source = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .topStatus:
                collectionView.dequeueConfiguredReusableCell(using: statusCell, for: indexPath, item: ())
            case let .row(id):
                collectionView.dequeueConfiguredReusableCell(using: rowCell, for: indexPath, item: id)
            }
        }
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func changedRowIDs(in next: MessageListContent) -> Set<String> {
        let nextEntries = Self.entries(for: next.rows)
        return Set(next.rows.compactMap { row in
            guard let previous = entries[row.id], previous != nextEntries[row.id] else { return nil }
            return row.id
        })
    }

    func apply(_ next: MessageListContent, changedRowIDs: Set<String>) {
        let statusChanged = content.topStatus != next.topStatus
            && content.topStatus != .none && next.topStatus != .none
        entries = Self.entries(for: next.rows)
        content = next

        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        if next.topStatus != .none {
            snapshot.appendItems([.topStatus])
        }
        snapshot.appendItems(next.rows.map { .row($0.id) })
        snapshot.reconfigureItems(changedRowIDs.map(Item.row) + (statusChanged ? [.topStatus] : []))
        source?.apply(snapshot, animatingDifferences: false)
    }

    func rowID(at indexPath: IndexPath) -> String? {
        guard case let .row(id) = source?.itemIdentifier(for: indexPath) else { return nil }
        return id
    }

    func indexPath(for id: String) -> IndexPath? {
        source?.indexPath(for: .row(id))
    }

    func frame(for id: String, in collectionView: UICollectionView) -> CGRect? {
        guard let indexPath = indexPath(for: id) else { return nil }
        return collectionView.layoutAttributesForItem(at: indexPath)?.frame
    }

    func visibleRows(in collectionView: UICollectionView) -> [(id: String, frame: CGRect)] {
        // Visible index paths lag behind an offset restoration until the next layout pass.
        let rect = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        let attributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: rect) ?? []
        return attributes.compactMap { attributes in
            guard attributes.representedElementCategory == .cell,
                  case let .row(id) = source?.itemIdentifier(for: attributes.indexPath) else { return nil }
            return (id: id, frame: attributes.frame)
        }
        .sorted { $0.frame.minY < $1.frame.minY }
    }

    private static func entries(for rows: [MessageRowState]) -> [String: Entry] {
        Dictionary(uniqueKeysWithValues: rows.enumerated().map { index, row in
            (row.id, Entry(row: row, isFirst: index == 0))
        })
    }
}
