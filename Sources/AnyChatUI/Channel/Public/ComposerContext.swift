import SwiftUI
import AnyChatDesignSystem

/// What a composer slot or the empty state needs: whether the user can send now, whether a response
/// is in progress, and the actions the default composer uses, such as opening the attachment pickers.
///
/// `composerLeadingItems(_:)`, `composerTrailingItems(_:)`, `composer(_:)`, and
/// `channelEmptyState(_:)` pass one to the host's closure.
/// It carries actions, so it is not `Hashable`.
///
/// - Since: 1.0.0
public struct ComposerContext {
    /// Whether a send is accepted now. `false` while the messages load, during a retry, and in a
    /// channel that does not allow sending. Composer items are disabled while it is `false`; a
    /// view passed to `composer(_:)` disables its own controls.
    ///
    /// - Since: 1.0.0
    public let canSend: Bool

    /// Whether the channel itself does not allow sending, as opposed to the messages still
    /// loading. Use `canSend` to enable controls, and this only to explain why they are disabled.
    ///
    /// - Since: 1.0.0
    public let isUnavailable: Bool

    /// Whether `openCamera()` can show the camera: the device has one and the app's Info.plist
    /// declares `NSCameraUsageDescription`.
    ///
    /// - Since: 1.0.0
    public let canOpenCamera: Bool
    /// The message the user is answering, or `nil`. While it is set, `send(text:)` and attachments
    /// picked from the composer send replies to it.
    ///
    /// - Since: 1.0.0
    public let replyingTo: ChatMessage?

    /// Whether a response is in progress, as passed to `composerStopButton(isResponding:action:)`.
    /// While it is `true` the default composer shows a stop button in place of send; draw your own
    /// from it in a `composer(_:)` view. It does not change `canSend`.
    ///
    /// ```swift
    /// if context.isResponding {
    ///     Button("Stop") { context.stop() }
    /// }
    /// ```
    ///
    /// - Since: 1.0.0
    public let isResponding: Bool

    private let showsAttachButton: Bool
    private let theme: ChannelTheme
    private let sendAction: (String) -> Void
    private let openAction: (ComposerPicker) -> Void
    private let cancelReplyAction: () -> Void
    private let stopAction: () -> Void

    init(
        canSend: Bool,
        isUnavailable: Bool,
        canOpenCamera: Bool,
        replyingTo: ChatMessage?,
        isResponding: Bool,
        showsAttachButton: Bool,
        theme: ChannelTheme,
        send: @escaping (String) -> Void,
        open: @escaping (ComposerPicker) -> Void,
        cancelReply: @escaping () -> Void,
        stop: @escaping () -> Void
    ) {
        self.canSend = canSend
        self.isUnavailable = isUnavailable
        self.canOpenCamera = canOpenCamera
        self.replyingTo = replyingTo
        self.isResponding = isResponding
        self.showsAttachButton = showsAttachButton
        self.theme = theme
        sendAction = send
        openAction = open
        cancelReplyAction = cancelReply
        stopAction = stop
    }

    /// The items the composer shows on this side when you do not set it: the attachment (+)
    /// button on the leading side, nothing on the trailing side. Put it in your closure to keep
    /// them. Empty in `composer(_:)` and `channelEmptyState(_:)`; use `openAttachmentMenu()` for
    /// your own + button there.
    ///
    /// - Since: 1.0.0
    @ViewBuilder
    public var defaultItems: some View {
        if showsAttachButton {
            ComposerAttachButton(theme: theme) { openAttachmentMenu() }
        }
    }

    /// Sends `text` as a message, trimmed of leading and trailing whitespace and newlines. It
    /// sends the given text, not the draft in the composer's field. While `replyingTo` is set it is
    /// sent as a reply, and the reply bar closes. Does nothing for empty text or while `canSend` is
    /// `false`.
    ///
    /// - Since: 1.0.0
    public func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !trimmed.isEmpty else {
            return
        }
        sendAction(trimmed)
    }

    /// Stops answering `replyingTo` and closes the reply bar. The draft stays. Does nothing while
    /// no reply is being written.
    ///
    /// - Since: 1.0.0
    public func cancelReply() {
        guard replyingTo != nil else {
            return
        }
        cancelReplyAction()
    }

    /// Calls the action passed to `composerStopButton(isResponding:action:)`. It works while `canSend`
    /// is `false`. Does nothing while `isResponding` is `false`.
    ///
    /// - Since: 1.0.0
    public func stop() {
        guard isResponding else {
            return
        }
        stopAction()
    }

    /// Shows the attachment menu: Camera (when available), Photo library, and Files. Does nothing
    /// while `canSend` is `false`.
    ///
    /// - Since: 1.0.0
    public func openAttachmentMenu() {
        open(.menu)
    }

    /// Shows the camera. Does nothing unless `canOpenCamera` and `canSend` are `true`.
    ///
    /// - Since: 1.0.0
    public func openCamera() {
        guard canOpenCamera else {
            return
        }
        open(.camera)
    }

    /// Shows the photo library picker for images and videos. Does nothing while `canSend` is
    /// `false`.
    ///
    /// - Since: 1.0.0
    public func openPhotoLibrary() {
        open(.photoLibrary)
    }

    /// Shows the file picker. Does nothing while `canSend` is `false`.
    ///
    /// - Since: 1.0.0
    public func openFiles() {
        open(.files)
    }

    private func open(_ picker: ComposerPicker) {
        guard canSend else {
            return
        }
        openAction(picker)
    }
}

enum ComposerPicker {
    case menu
    case camera
    case photoLibrary
    case files
}

/// The default + button. It applies no `.disabled` of its own: inside a host's items it sits in
/// the adopted environment, where writing `isEnabled` is what once leaked back into the
/// representable. Its tint follows the `isEnabled` it is given.
private struct ComposerAttachButton: View {
    let theme: ChannelTheme
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(theme.composerFont)
                .foregroundStyle(isEnabled ? theme.composerButtonTint : theme.composerDisabledTint)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
            .buttonStyle(.plain)
            .modifier(GlassSurface(tint: theme.composerFieldBackground))
            .accessibilityLabel("Attach")
    }
}
