import SwiftUI

/// The centred empty / error state: a 64pt glyph, a line of text, and an optional retry button.
package struct Placeholder: View {
    /// The button below the message. Leaving it out gives the shorter design source variant.
    package struct Retry {
        let title: String
        let tint: Color
        let action: () -> Void

        package init(title: String, tint: Color, action: @escaping () -> Void) {
            self.title = title
            self.tint = tint
            self.action = action
        }
    }

    private static let width: CGFloat = 200
    private static let glyphLength: CGFloat = 64

    private let icon: ChatIcon
    private let text: String
    private let tint: Color
    private let font: Font
    private let retry: Retry?

    package init(
        icon: ChatIcon,
        text: String,
        tint: Color,
        font: Font,
        retry: Retry? = nil
    ) {
        self.icon = icon
        self.text = text
        self.tint = tint
        self.font = font
        self.retry = retry
    }

    package var body: some View {
        VStack(spacing: 16) {
            icon.sized(Self.glyphLength)
                .foregroundStyle(tint)

            Text(text)
                .font(font)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)

            if let retry {
                Button(retry.title, action: retry.action)
                    .font(ChatTypography.button)
                    .tint(retry.tint)
                    .frame(minWidth: 88, minHeight: 32)
            }
        }
        .frame(width: Self.width)
    }
}

#Preview("States") {
    VStack(spacing: 40) {
        Placeholder(icon: .chat, text: "No channels", tint: .gray, font: ChatTypography.body)
        Placeholder(
            icon: .error,
            text: "Something went wrong",
            tint: .gray,
            font: ChatTypography.body,
            retry: .init(title: "Retry", tint: ChatPalette.light.accent) {}
        )
    }
    .padding()
}
