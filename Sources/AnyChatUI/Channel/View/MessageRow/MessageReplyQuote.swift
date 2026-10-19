import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// The default quote above a reply's bubble: the "replied to" line and an outlined copy of the
/// original's text, or its first picture.
struct MessageReplyQuote: View {
    let quote: ReplyQuote
    let isMine: Bool

    @Environment(\.channelTheme) private var theme

    private static let spacing: CGFloat = 4
    private static let lineInset: CGFloat = 12
    private static let cornerRadius: CGFloat = 18
    private static let borderWidth: CGFloat = 1
    /// The design source's padding sits inside its 1pt border.
    private static let horizontalPadding: CGFloat = 12 + borderWidth
    private static let verticalPadding: CGFloat = 7 + borderWidth
    private static let lineSpacing: CGFloat = 20 - UIFont.systemFont(ofSize: 15).lineHeight
    private static let minHeight: CGFloat = 20 + 2 * verticalPadding
    private static let maxWidth: CGFloat = 240
    private static let maxLines = 2
    private static let thumbnailSide: CGFloat = 56
    private static let thumbnailCornerRadius: CGFloat = 12
    private static let thumbnailMetrics = MediaThumbnail.Metrics(placeholderIconSize: 20, badgeSize: 20, badgeIconSize: 12)

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: Self.spacing) {
            Text(quote.line)
                .font(theme.senderNameFont)
                .foregroundStyle(theme.senderNameText)
                .padding(.horizontal, Self.lineInset)
            if let thumbnail = quote.thumbnail {
                MediaThumbnail(attachment: thumbnail, metrics: Self.thumbnailMetrics)
                    .frame(width: Self.thumbnailSide, height: Self.thumbnailSide)
                    .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius, style: .continuous))
            } else {
                Text(quote.text)
                    .font(theme.replyQuoteFont)
                    .foregroundStyle(quote.isUnavailable ? theme.senderNameText : theme.replyQuoteText)
                    .lineLimit(Self.maxLines)
                    .lineSpacing(Self.lineSpacing)
                    .padding(.horizontal, Self.horizontalPadding)
                    .padding(.vertical, Self.verticalPadding)
                    .frame(minHeight: Self.minHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .strokeBorder(theme.replyQuoteBorder, style: StrokeStyle(lineWidth: Self.borderWidth, dash: quote.isUnavailable ? [4, 3] : []))
                    }
                    .frame(maxWidth: Self.maxWidth, alignment: isMine ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
