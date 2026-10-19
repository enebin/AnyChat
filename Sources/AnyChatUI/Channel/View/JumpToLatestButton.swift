import Observation
import AnyChatDesignSystem
import SwiftUI

/// What the hosted jump-to-latest button reads. Hosting does not pass the outer environment down,
/// so it travels here, and only the host's view adopts it, as with the composer
/// (`ComposerPresentation`).
@Observable
final class JumpToLatestPresentation {
    var slot: ((@escaping () -> Void) -> AnyView)?
    var theme = ChannelTheme()
    var environment = EnvironmentValues()
    var isVisible = false
    var onJump: () -> Void = {}

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}
}

/// The round button above the composer that returns to the newest message, or the host's
/// `jumpToLatestButton` view, shown while the list is away from the bottom.
///
/// It stays in the hierarchy while hidden, so its size, and the hosting view's, do not change
/// while it fades out.
struct JumpToLatestButton: View {
    let presentation: JumpToLatestPresentation

    private static let side: CGFloat = 44
    private static let hiddenScale: CGFloat = 0.5

    var body: some View {
        content
            .opacity(presentation.isVisible ? 1 : 0)
            .scaleEffect(presentation.isVisible ? 1 : Self.hiddenScale)
            .allowsHitTesting(presentation.isVisible)
            .animation(.smooth(duration: 0.25), value: presentation.isVisible)
    }

    @ViewBuilder
    private var content: some View {
        if let slot = presentation.slot {
            slot { presentation.onJump() }
                .environment(\.self, presentation.environment)
        } else {
            Button { presentation.onJump() } label: {
                ChatIcon.jumpToLatest.image
                    .font(presentation.theme.composerFont)
                    .foregroundStyle(presentation.theme.composerButtonTint)
                    .frame(width: Self.side, height: Self.side)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(GlassSurface(tint: presentation.theme.composerFieldBackground, shape: Circle()))
            .accessibilityLabel("Jump to latest")
        }
    }
}
