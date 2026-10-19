import Observation
import SwiftUI

/// What the hosted composer reads. Hosting does not pass the outer environment down, so it
/// travels here.
///
/// The package's own controls read only `theme`: adopting the representable's `EnvironmentValues`
/// shares its read tracker with the hosted graph, and the composer's own `.disabled(true)` once came
/// back through `context.environment.isEnabled`, keeping the attachment button disabled for good.
/// The host's items get `environment` with `isEnabled` written into the copy and nothing written
/// between it and them (`MessageComposer.hostItems`); the host's `composer` view gets it as is
/// (`ComposerRoot.bar`).
@Observable
final class ComposerPresentation {
    var theme = ChannelTheme()
    var isEnabled = false
    /// The channel itself does not allow sending, as opposed to the list still loading.
    var isUnavailable = false
    /// The message being answered, and what the default bar shows of it.
    var replyingTo: ChatMessage?
    var replyBarText: ReplyBarText?
    var replyBar: ((ChatMessage, ComposerContext) -> AnyView)?
    var onCancelReply: () -> Void = {}
    /// How far the keyboard has risen over its first stretch, from 0 (hidden) to 1.
    var keyboardProgress: CGFloat = 0
    var placeholder: String?
    /// The screen's environment, given to the host's items, `composer` view, and background only.
    var environment = EnvironmentValues()
    var leadingItems: ((ComposerContext) -> AnyView)?
    var trailingItems: ((ComposerContext) -> AnyView)?
    var itemsInsideField = false
    var sendButtonLabel: (() -> AnyView)?
    var isResponding = false
    var onStop: () -> Void = {}
    var composer: ((ComposerContext) -> AnyView)?
    var background: (() -> AnyView)?
    var onSend: (String) -> Void = { _ in }
    var onAttach: ([AttachmentSource]) -> Void = { _ in }
    var onAttachFailure: () -> Void = {}
    /// The pickers live here rather than in the composer's view, so the empty state's context can
    /// open them too.
    var isShowingMenu = false
    var isShowingCamera = false
    var isShowingPhotoLibrary = false
    var isShowingFiles = false

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    /// What the default bar shows after the field. Stop wins over send whatever the draft, so a
    /// response in progress can always be stopped.
    func trailingControl(hasDraft: Bool) -> TrailingControl {
        if isResponding {
            return .stop
        }
        if isEnabled && hasDraft {
            return .send
        }
        return .items
    }

    /// The one source of `ComposerContext`, for the composer slots and the empty state alike.
    func context(showsAttachButton: Bool) -> ComposerContext {
        ComposerContext(
            canSend: isEnabled,
            isUnavailable: isUnavailable,
            canOpenCamera: CameraPicker.canTakePhotos,
            replyingTo: replyingTo,
            isResponding: isResponding,
            showsAttachButton: showsAttachButton,
            theme: theme,
            send: onSend,
            open: { [weak self] picker in self?.open(picker) },
            cancelReply: onCancelReply,
            stop: onStop
        )
    }

    private func open(_ picker: ComposerPicker) {
        switch picker {
        case .menu: isShowingMenu = true
        case .camera: isShowingCamera = true
        case .photoLibrary: isShowingPhotoLibrary = true
        case .files: isShowingFiles = true
        }
    }

    /// The design source's unavailable text wins over the host's placeholder, because it explains
    /// the disabled field.
    var placeholderText: String {
        if isUnavailable {
            return "Chat is unavailable in this channel"
        }
        return placeholder ?? "Enter message"
    }
}

enum TrailingControl {
    case stop
    case send
    case items
}
