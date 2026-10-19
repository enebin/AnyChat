import SwiftUI

/// The 1pt separator.
///
/// Named apart from SwiftUI's own `Divider`, which cannot be tinted directly. A `List` draws its
/// own separators, so this is for content outside one.
package struct DividerLine: View {
    private let color: Color

    package init(color: Color) {
        self.color = color
    }

    package var body: some View {
        color.frame(height: 1)
    }
}

#Preview("Divider") {
    VStack(spacing: 12) {
        Text("Above")
        DividerLine(color: .gray.opacity(0.3))
        Text("Below")
    }
    .padding()
}
