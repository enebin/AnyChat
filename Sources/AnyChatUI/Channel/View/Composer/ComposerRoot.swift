import SwiftUI

/// The hosted composer: the default bar or the host's own composer, with the attachment pickers
/// around it, so the pickers open from the + button, a host's items, and a host's composer alike.
struct ComposerRoot: View {
    @Bindable var presentation: ComposerPresentation
    let onHeightChange: (CGFloat) -> Void

    private static let replyBarSpacing: CGFloat = 8

    var body: some View {
        // The default bar's own vertical padding already sits between it and the reply bar.
        VStack(spacing: presentation.composer == nil ? Self.replyBarSpacing - MessageComposer.verticalPadding : Self.replyBarSpacing) {
            replyBar
                .padding(.horizontal, sharesTheBarInset ? 0 : keyboardInset)
                // A bar that appears while the keyboard rises takes its final width at once while
                // the composer below still narrows; fading it in over the same time hides that.
                .transition(.opacity.animation(.smooth(duration: 0.25)))
            bar
        }
        // One animated inset around both, so a reply bar that appears while the keyboard is still
        // rising narrows with the bar instead of starting at the final width.
        .padding(.horizontal, sharesTheBarInset ? keyboardInset : 0)
        .animation(.smooth(duration: 0.25), value: presentation.keyboardProgress)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            onHeightChange(height)
        }
        .modifier(AttachmentPickers(
            isShowingMenu: $presentation.isShowingMenu,
            isShowingCamera: $presentation.isShowingCamera,
            isShowingPhotoLibrary: $presentation.isShowingPhotoLibrary,
            isShowingFiles: $presentation.isShowingFiles,
            onPick: presentation.onAttach,
            onFailure: presentation.onAttachFailure
        ))
    }

    /// A host's composer gets the environment unchanged: it decides which of its controls to
    /// disable, because some, such as a stop button, must work while sending is unavailable.
    @ViewBuilder
    private var bar: some View {
        if let composer = presentation.composer {
            composer(context(showsAttachButton: false))
                .environment(\.self, presentation.environment)
        } else {
            MessageComposer(
                presentation: presentation,
                leadingContext: context(showsAttachButton: true),
                trailingContext: context(showsAttachButton: false)
            )
        }
    }

    /// The default bar's side padding follows the keyboard; the capsule layout and a host's
    /// composer keep their own, and only the reply bar takes the keyboard inset there.
    private var sharesTheBarInset: Bool {
        presentation.composer == nil && !presentation.itemsInsideField
    }

    private var keyboardInset: CGFloat {
        MessageComposer.sidePadding(keyboardProgress: presentation.keyboardProgress)
    }

    /// Resolved first so a slot that returns nothing removes the bar and its spacing, which a host
    /// `composer` that draws its own bar relies on.
    @ViewBuilder
    private var replyBar: some View {
        if let message = presentation.replyingTo, let text = presentation.replyBarText {
            if let slot = presentation.replyBar {
                Group(subviews: slot(message, context(showsAttachButton: false)).environment(\.self, presentation.environment)) { subviews in
                    ForEach(subviews) { $0 }
                }
            } else {
                ComposerReplyBar(text: text, theme: presentation.theme) {
                    presentation.onCancelReply()
                }
            }
        }
    }

    private func context(showsAttachButton: Bool) -> ComposerContext {
        presentation.context(showsAttachButton: showsAttachButton)
    }
}
