import Observation
import AnyChatDesignSystem
import SwiftUI

/// What the hosted empty state reads besides the composer. Hosting does not pass the outer
/// environment down, so it travels here, and only the host's view adopts it, as with the composer
/// (`ComposerPresentation`).
@Observable
final class EmptyStatePresentation {
    var slot: ((ComposerContext) -> AnyView)?
    var theme = ChannelTheme()
    var environment = EnvironmentValues()
    /// From the hosting view's bottom edge up to the composer's top.
    var bottomInset: CGFloat = 0
    /// `false` for the inset set as the view appears, so the content does not slide into place.
    var animatesInset = false

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}
}

/// The host's `channelEmptyState` view, or "No messages", centered above the composer.
///
/// The hosting view keeps its size while the keyboard moves, and the content follows through an
/// animated bottom inset. A hosting view resized inside the keyboard's animation lays its content
/// out for the final size at once, so content at the bottom jumped ahead of the composer.
struct ChannelEmptyState: View {
    let presentation: EmptyStatePresentation
    /// Read here, so the slot's context follows `canSend` like the composer's own.
    let composer: ComposerPresentation

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, presentation.bottomInset)
            .animation(presentation.animatesInset ? .smooth(duration: 0.25) : nil, value: presentation.bottomInset)
    }

    @ViewBuilder
    private var content: some View {
        if let slot = presentation.slot {
            slot(composer.context(showsAttachButton: false))
                .environment(\.self, presentation.environment)
        } else {
            Placeholder(
                icon: .message,
                text: "No messages",
                tint: presentation.theme.placeholderTint,
                font: presentation.theme.messageFont
            )
        }
    }
}
