import SwiftUI

/// The capsule count badge.
package struct Badge: View {
    private static let height: CGFloat = 20

    private let text: String
    private let font: Font
    private let foreground: Color
    private let background: Color

    package init(_ text: String, font: Font, foreground: Color, background: Color) {
        self.text = text
        self.font = font
        self.foreground = foreground
        self.background = background
    }

    package var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .frame(minWidth: Self.height, minHeight: Self.height)
            .background(background, in: .capsule)
    }
}

#Preview("Counts") {
    HStack {
        ForEach(["1", "99", "99+"], id: \.self) { text in
            Badge(text, font: ChatTypography.captionEmphasized, foreground: .white, background: ChatPalette.light.accent)
        }
    }
    .padding()
}
