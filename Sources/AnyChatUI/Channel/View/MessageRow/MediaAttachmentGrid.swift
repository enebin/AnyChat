import AnyChatCore
import SwiftUI

/// Two or more images, GIFs, or videos in two columns.
struct MediaAttachmentGrid: View {
    let attachments: [ChatAttachment]
    let isMine: Bool
    let onSelect: ((ChatAttachment) -> Void)?

    @Environment(\.channelTheme) private var theme

    private static let width: CGFloat = 240
    private static let padding: CGFloat = 4
    private static let spacing: CGFloat = 4
    private static let cornerRadius: CGFloat = 16
    private static let outerCellCornerRadius: CGFloat = 12
    private static let innerCellCornerRadius: CGFloat = 6
    private static let cellSize = (width - padding * 2 - spacing) / 2
    private static let metrics = MediaThumbnail.Metrics(placeholderIconSize: 24, badgeSize: 32, badgeIconSize: 18)

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(Array(stride(from: 0, to: attachments.count, by: 2)), id: \.self) { start in
                HStack(spacing: Self.spacing) {
                    let indices = Array(start..<min(start + 2, attachments.count))
                    if indices.count == 1 && isMine {
                        Spacer(minLength: 0)
                    }
                    ForEach(indices, id: \.self) { index in
                        cell(at: index)
                    }
                    if indices.count == 1 && !isMine {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .background(theme.incomingBubbleBackground, in: .rect(cornerRadius: Self.cornerRadius))
    }

    private func cell(at index: Int) -> some View {
        let attachment = attachments[index]
        let shape = UnevenRoundedRectangle(
            cornerRadii: Self.cornerRadii(index: index, count: attachments.count, isMine: isMine)
        )
        return MediaThumbnail(attachment: attachment, metrics: Self.metrics)
            .frame(width: Self.cellSize, height: Self.cellSize)
            .clipShape(shape)
            .contentShape(shape)
            .attachmentTap(onSelect.map { action in { action(attachment) } })
    }

    /// A cell follows the grid's rounding where it meets one of the grid's corners. An odd last
    /// cell sits on the sender's side, so it meets only that side's bottom corner.
    static func cornerRadii(index: Int, count: Int, isMine: Bool) -> RectangleCornerRadii {
        let row = index / 2
        let lastRow = (count - 1) / 2
        let isLone = row == lastRow && count.isMultiple(of: 2) == false
        let column = isLone ? (isMine ? 1 : 0) : index % 2

        func radius(_ meetsCorner: Bool) -> CGFloat {
            meetsCorner ? outerCellCornerRadius : innerCellCornerRadius
        }
        return RectangleCornerRadii(
            topLeading: radius(row == 0 && column == 0),
            bottomLeading: radius(row == lastRow && column == 0),
            bottomTrailing: radius(row == lastRow && column == 1),
            topTrailing: radius(row == 0 && column == 1)
        )
    }
}
