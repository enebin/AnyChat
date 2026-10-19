import SwiftUI

/// Explains why nobody can send. Whether sending works comes from `canSendMessage`, not from here.
struct FrozenBanner: View {
    @Environment(\.channelTheme) private var theme

    private let height: CGFloat = 24
    private let outerPadding: CGFloat = 8
    private let textPadding: CGFloat = 12
    private let cornerRadius: CGFloat = 4

    var body: some View {
        Text("Channel is frozen")
            .font(theme.frozenBannerFont)
            .foregroundStyle(theme.frozenBannerText)
            .lineLimit(1)
            .padding(.horizontal, textPadding)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(theme.frozenBannerBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            .padding(outerPadding)
    }
}
