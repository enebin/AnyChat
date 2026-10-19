import SwiftUI

/// A 32pt tappable square holding a 24pt icon.
///
/// Deliberately leaves the button style alone: inside a toolbar, iOS draws its own background
/// and a `.plain` style here would remove it.
package struct IconButton: View {
    private static let side: CGFloat = 32
    private static let iconLength: CGFloat = 24

    private let icon: ChatIcon
    private let tint: Color
    private let action: () -> Void

    package init(_ icon: ChatIcon, tint: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    package var body: some View {
        Button(action: action) {
            icon.sized(Self.iconLength)
                .frame(width: Self.side, height: Self.side)
        }
        .tint(tint)
    }
}

#Preview("Buttons") {
    HStack {
        IconButton(.create, tint: ChatPalette.light.accent) {}
        IconButton(.search, tint: ChatPalette.light.accent) {}
    }
    .padding()
}
