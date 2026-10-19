import SwiftUI

struct SystemMessageRow: View {
    let text: String

    @Environment(\.channelTheme) private var theme

    private static let maxWidth: CGFloat = 300

    var body: some View {
        Text(text)
            .font(theme.systemMessageFont)
            .foregroundStyle(theme.systemMessageText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: Self.maxWidth)
            .frame(maxWidth: .infinity)
    }
}
