import SwiftUI

/// The host's `composerBackground` view, filling the backdrop from the composer's top edge down to
/// the screen's bottom edge.
struct ComposerBackground: View {
    let presentation: ComposerPresentation

    var body: some View {
        if let background = presentation.background {
            background()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.self, presentation.environment)
        }
    }
}
