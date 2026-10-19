import SwiftUI

package struct GlassSurface<SurfaceShape: Shape>: ViewModifier {
    package let tint: Color
    package let shape: SurfaceShape

    package init(tint: Color, shape: SurfaceShape) {
        self.tint = tint
        self.shape = shape
    }

    @ViewBuilder
    package func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.4)), in: shape)
        } else {
            content.background(tint, in: shape)
        }
    }
}

package extension GlassSurface where SurfaceShape == Capsule {
    init(tint: Color) {
        self.init(tint: tint, shape: Capsule())
    }
}
