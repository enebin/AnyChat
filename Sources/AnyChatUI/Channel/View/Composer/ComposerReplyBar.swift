import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// The default bar above the composer while the user answers a message: whom they answer, a
/// one-line preview of the message, and a button that closes it.
struct ComposerReplyBar: View {
    let text: ReplyBarText
    let theme: ChannelTheme
    let onCancel: () -> Void

    private static let height: CGFloat = 52
    private static let leadingInset: CGFloat = 16
    private static let trailingInset: CGFloat = 4
    private static let titleLineHeight: CGFloat = 18
    private static let previewLineHeight: CGFloat = 20
    private static let closeTarget: CGFloat = 44
    private static let closeSide: CGFloat = 30
    private static let closeGlyph: CGFloat = 10

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(text.title)
                    .font(theme.replyBarTitleFont)
                    .foregroundStyle(theme.composerText)
                    .lineLimit(1)
                    .frame(minHeight: Self.titleLineHeight)
                Text(text.preview)
                    .font(theme.replyQuoteFont)
                    .foregroundStyle(theme.replyQuoteText)
                    .lineLimit(1)
                    .frame(minHeight: Self.previewLineHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: Self.closeGlyph, weight: .bold))
                    .foregroundStyle(theme.senderNameText)
                    .frame(width: Self.closeSide, height: Self.closeSide)
                    .background(theme.replyBarCloseBackground, in: .circle)
                    .frame(width: Self.closeTarget, height: Self.closeTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.leading, Self.leadingInset)
        .padding(.trailing, Self.trailingInset)
        .frame(height: Self.height)
        .modifier(GlassSurface(tint: theme.composerFieldBackground))
    }
}
