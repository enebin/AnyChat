import AnyChatCore
import SwiftUI

/// The messages of one channel, newest at the bottom.
///
/// Push it from `ChannelListView.onChannelSelected` inside your own `NavigationStack`. It loads
/// from the backend registered with `chatBackend(_:)`.
///
/// ```swift
/// ChannelListView()
///     .onChannelSelected { selected = $0 }
///     .navigationDestination(item: $selected) { ChannelView(channel: $0) }
/// ```
///
/// The composer sends text and attachments from the photo library and files. It offers the
/// camera only when your app's Info.plist describes camera use, and video capture only when it
/// also describes microphone use:
///
/// ```
/// INFOPLIST_KEY_NSCameraUsageDescription: Take photos and videos to send in a channel.
/// INFOPLIST_KEY_NSMicrophoneUsageDescription: Record sound with videos you send in a channel.
/// ```
///
/// - Since: 1.0.0
public struct ChannelView: View {
    private let channel: ChatChannel
    /// Set by the overriding initializer, which bypasses the environment.
    private let override: Override?

    var slots = ChannelSlots()

    @Environment(\.chatBackend) private var backend
    @Environment(\.channelTheme) private var theme

    private struct Override {
        let repository: any ChannelRepository
        let currentUserID: String?
    }

    /// The store depends on the backend and on the channel, so a change to either starts a new one.
    private struct Identity: Hashable {
        let backend: ObjectIdentifier
        let channelID: String
    }

    /// Creates a channel screen that loads from the backend registered with `chatBackend(_:)`.
    ///
    /// The header, the frozen banner, and whether the composer can send follow the latest `channel`
    /// you pass with the same `id`. The screen does not observe the channel from the backend, so
    /// pass a newer value to show a rename or a freeze. A different `id` starts a new screen.
    ///
    /// - Since: 1.0.0
    public init(channel: ChatChannel) {
        self.channel = channel
        self.override = nil
    }

    /// Creates a channel screen around a repository of your own, ignoring any registered backend.
    ///
    /// It follows newer values of `channel` the same way as ``init(channel:)``.
    ///
    /// `currentUserID` decides which messages are drawn as the current user's. With `nil`, every
    /// sent message is drawn as someone else's, including one this device just sent: it is drawn
    /// as the current user's only while it is pending or failed.
    ///
    /// - Since: 1.0.0
    public init(channel: ChatChannel, repository: any ChannelRepository, currentUserID: String?) {
        self.channel = channel
        self.override = Override(repository: repository, currentUserID: currentUserID)
    }

    public var body: some View {
        if let override {
            content(repository: override.repository, currentUserID: override.currentUserID)
                .id(channel.id)
        } else if let backend {
            content(
                repository: backend.makeChannelRepository(channelID: channel.id),
                currentUserID: backend.currentUserID
            )
            .id(Identity(backend: ObjectIdentifier(backend), channelID: channel.id))
        } else {
            MissingBackendView(
                screenName: "ChannelView",
                tint: theme.placeholderTint,
                font: theme.messageFont,
                background: theme.background
            )
        }
    }

    private func content(repository: any ChannelRepository, currentUserID: String?) -> some View {
        ChannelContent(channel: channel, repository: repository, currentUserID: currentUserID, slots: slots)
    }
}

public extension ChannelView {
    /// Replaces the default centered header with a view at the leading edge of the navigation bar.
    ///
    /// The view is shown at its ideal size, so the navigation bar does
    /// not clip it and you do not need `.fixedSize()`. Long text is not truncated for you: give
    /// the text an explicit width with `.frame(width:)` and a `lineLimit` to cap it. The bar does
    /// not grow, so keep the view within its height; a picture, a name, and a one-line subtitle fit.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .channelHeader { channel in
    ///         VStack(alignment: .leading, spacing: 0) {
    ///             Text(channel.name ?? "Chat").font(.headline)
    ///             Text("Active now").font(.caption).foregroundStyle(.secondary)
    ///         }
    ///     }
    /// ```
    ///
    /// Return no view to hide the header. The screen then adds no item at the leading edge, so a
    /// `toolbar` item of your own takes that spot. The default channel name below the bar stays
    /// hidden, as it does whenever this slot is set:
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .channelHeader { _ in EmptyView() }
    ///     .toolbar {
    ///         ToolbarItem(placement: .topBarLeading) {
    ///             Button("Chats", systemImage: "line.3.horizontal") { showsChats = true }
    ///         }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func channelHeader(@ViewBuilder _ content: @escaping (ChatChannel) -> some View) -> Self {
        var copy = self
        copy.slots.header = { AnyView(content($0)) }
        return copy
    }

    /// Replaces the "No messages" placeholder of a channel that has no messages yet.
    ///
    /// The view fills the list's area between the header and the composer, centered, and moves up
    /// with the composer when the keyboard opens. The composer stays usable below it. The view
    /// goes away as soon as the channel has a message, including one the user just sent that is
    /// still pending. Use a `Spacer` to place it at the top or the bottom of that area. A drag on
    /// the view still dismisses the keyboard, and its buttons take their own taps.
    ///
    /// `composer` is the screen's `ComposerContext`, the same one the composer slots get. Its
    /// `send(text:)` sends through the screen like the composer does, for example a suggested
    /// prompt, and its `openPhotoLibrary()` and the other pickers open the composer's pickers.
    /// Disable your buttons while `composer.canSend` is `false`, such as while the messages load or
    /// in a channel that does not allow sending.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .channelEmptyState { composer in
    ///         VStack(spacing: 8) {
    ///             Spacer()
    ///             Text("No messages yet").font(.headline)
    ///             Button("Say hi 👋") { composer.send(text: "Hi 👋") }
    ///                 .disabled(!composer.canSend)
    ///         }
    ///         .padding(.bottom, 16)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func channelEmptyState(@ViewBuilder _ content: @escaping (ComposerContext) -> some View) -> Self {
        var copy = self
        copy.slots.emptyState = { AnyView(content($0)) }
        return copy
    }

    /// Replaces a whole message row, including the sender's name, picture and time. Date
    /// separators and pagination still work.
    ///
    /// The message signals still work around whatever the slot draws: a long press opens the
    /// menu, which lifts the whole slot view, and tapping a failed message opens its dialog (by default Retry and Remove). Buttons
    /// and tap gestures inside the slot get the tap first, so a tap gesture that covers the whole
    /// slot hides that dialog; leave it off while `message.sendingStatus` is `.failed`. Declare
    /// menu items with `messageContextMenu(_:)` rather than a `.contextMenu` inside the slot. Use
    /// `message.sendingStatus` to show the pending and failed states.
    ///
    /// `messageLongPressOverlay(above:below:)` lifts a new copy of the whole row, unscaled, in
    /// which view-local `@State` starts fresh. Keep state that must survive it in the message or
    /// your own model.
    ///
    /// - Since: 1.0.0
    func messageRow(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageRow = { AnyView(content($0, $1)) }
        return copy
    }

    /// Replaces the bubble of a user's message, keeping the sender's name, picture, time and
    /// receipt around it. System messages are not passed here.
    ///
    /// The closure runs again whenever the message changes in place, such as streamed text.
    ///
    /// A long press on the slot's view still opens the message menu, which lifts that view alone.
    /// Declare menu items with `messageContextMenu(_:)` rather than a `.contextMenu` inside the
    /// slot, which would compete with it.
    ///
    /// `messageLongPressOverlay(above:below:)` lifts a new copy of the slot's view, in which
    /// view-local `@State` starts fresh. Keep state that must survive it, such as an expanded
    /// "Read more", in the message or your own model.
    ///
    /// - Since: 1.0.0
    func messageContent(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageContent = { AnyView(content($0, $1)) }
        return copy
    }

    /// Replaces what is drawn behind a text bubble, such as a shape with a tail or a gradient fill,
    /// while the screen keeps drawing the text, attachments, time, and receipt.
    ///
    /// It applies to the default text bubbles: a text message, the text below attachments, and
    /// the placeholder for unsupported content. Media, file bubbles, system messages, and bubbles
    /// drawn by `messageContent(_:)` or `messageRow(_:)` keep their own look. Use `context` to
    /// follow the side and the position in a run, for example a tail only when
    /// `context.groupPosition` is `.single` or `.last`.
    ///
    /// The view fills the bubble's frame and does not change its size. Nothing is reserved for a
    /// tail, so keep a tail within the spacing beside the bubble. The text still uses the theme's
    /// `incomingMessageText` and `outgoingMessageText`; set them for a fill they must stay readable on.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageBubbleBackground { _, context in
    ///         RoundedRectangle(cornerRadius: 20)
    ///             .fill(context.isMine ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.quaternary))
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageBubbleBackground(
        @ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.messageBubbleBackground = { AnyView(content($0, $1)) }
        return copy
    }

    /// Changes the space between a text bubble's edge and its text, and how wide the bubble can
    /// grow, while the screen keeps drawing the bubble.
    ///
    /// It applies to the same bubbles as `messageBubbleBackground(_:)`: a text message, the text
    /// below attachments, and the placeholder for unsupported content. Media, file bubbles, reply
    /// quotes, system messages, and bubbles drawn by `messageContent(_:)` or `messageRow(_:)` keep
    /// their own size.
    ///
    /// Pass only what you want to change; `nil` keeps the default or the value from an earlier
    /// call. The defaults are 9pt above and below the text, 14pt beside it, and a maximum width of
    /// 240pt. `maxWidth` is the whole bubble's width, insets included. A one-line bubble is at
    /// least 22pt plus the top and bottom insets tall. The default fill draws its tail below the
    /// bottom inset, on the last bubble of a run; a `messageBubbleBackground(_:)` view fills the
    /// insets exactly, so give it insets that clear its corner radius.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageBubbleLayout(insets: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    ///     .messageBubbleBackground { _, _ in
    ///         RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.gray.opacity(0.15))
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageBubbleLayout(insets: EdgeInsets? = nil, maxWidth: CGFloat? = nil) -> Self {
        var copy = self
        if let insets {
            copy.slots.messageBubbleLayout.insets = insets
        }
        if let maxWidth {
            copy.slots.messageBubbleLayout.maxWidth = maxWidth
        }
        return copy
    }

    /// Replaces the quote of the original above a reply's bubble.
    ///
    /// It is called only for messages whose `replyTo` is set; read the original from
    /// `message.replyTo` and the reply's sender from `message.sender`. `context.isMine` describes
    /// the reply, not the original: to say "Mina replied to you", capture the current user's id
    /// from the code that builds the screen and compare it with `message.replyTo?.sender?.id`.
    /// The default draws a "replied to" line in the sender name's style and an
    /// outlined copy of the original's text, or its first picture, with "Original message
    /// unavailable" when `replyTo.isUnavailable` is `true`. Return nothing to hide the quote and
    /// its spacing.
    ///
    /// The view sits in the bubble column, above the bubble and below the sender's name, aligned to
    /// the sender's side. The default's `ChannelTheme.replyQuoteText`, `replyQuoteBorder`, and
    /// `replyQuoteFont` are not applied; read `channelTheme` from the environment to use them. It
    /// applies around the default
    /// bubble and around `messageContent(_:)`, but not around `messageRow(_:)`, which draws its own
    /// quote. Quotes are drawn whatever `ChatChannel.canReply` says. The message menu lifts the
    /// bubble alone, so a long press on the quote opens nothing; tapping it does nothing unless the
    /// view holds a `Button`.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageReplyQuote { message, _ in
    ///         if let original = message.replyTo, !original.isUnavailable {
    ///             Label(original.sender?.name ?? "Message", systemImage: "arrowshape.turn.up.left")
    ///                 .font(.caption)
    ///         }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageReplyQuote(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageReplyQuote = { AnyView(content($0, $1)) }
        return copy
    }

    /// Adds a view below a user message's bubble, such as reaction badges, without replacing the
    /// bubble or the row. System messages are not passed here.
    ///
    /// The view sits 4pt below the bubble, or below its receipt or sending status when present,
    /// aligned to the sender's side. Custom pictures and times stay beside the bubble. Return
    /// nothing to add nothing, for example when the message has no reactions. Read app state
    /// from `message.attributes`; the closure runs again whenever
    /// the message changes in place. It is called for pending and failed messages too, so check
    /// `message.sendingStatus` to show something only once a message is sent.
    ///
    /// It applies around the default bubble and around `messageContent(_:)`, but not around
    /// `messageRow(_:)`, which draws the whole row and its own accessory. The message menu lifts
    /// the bubble alone, so a long press on this view opens nothing; buttons inside it get their
    /// taps first.
    /// To overlap the bubble's bottom edge, use negative top padding that also accounts for
    /// any receipt or sending status above the accessory.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageAccessory { message, context in
    ///         if let reactions = message.attributes[Reactions.self] {
    ///             ReactionBadges(reactions)
    ///         }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageAccessory(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageAccessory = { AnyView(content($0, $1)) }
        return copy
    }

    /// Adds a sender picture beside other people's messages, keeping the rest of the row,
    /// for example to draw initials.
    ///
    /// The default layout has no pictures beside bubbles. The closure is called for every incoming
    /// row. Its view shows on the last row of a run and keeps its size on the rows above it, so the
    /// bubbles line up. Return a view of the same size for every message, including when
    /// `message.sender` is `nil`. The view sets its own size. It sits
    /// 12pt from the bubble, aligned to the bubble's bottom.
    ///
    /// Return nothing to remove the picture and its spacing, so the bubbles start at the leading
    /// margin, for example in a one-to-one channel. Do this for every message of the screen;
    /// returning nothing for some messages only misaligns those rows.
    ///
    /// It applies around the default bubble and around `messageContent(_:)`, but not around
    /// `messageRow(_:)` or system messages. The theme's avatar placeholder colors are not applied;
    /// read `channelTheme` from the environment to use them. The view is built on the hidden rows
    /// too, so a picture loaded from a URL is requested for them as well.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageAvatar { message, _ in
    ///         Text(message.sender?.name?.prefix(1) ?? "?")
    ///             .frame(width: 32, height: 32)
    ///             .background(.gray.opacity(0.2), in: .circle)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageAvatar(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageAvatar = { AnyView(content($0, $1)) }
        return copy
    }

    /// Replaces the sender's name above other people's messages, keeping the rest of the row.
    ///
    /// The closure is called where the default name goes: the first row of a run of one person's
    /// messages. It is called when `message.sender` or its name is `nil` too, so decide what to
    /// show then. The view sits above the bubble with the default name's leading inset. The theme's
    /// `senderNameFont` and `senderNameText` are not applied; read `channelTheme` from the
    /// environment to use them.
    ///
    /// Return nothing to hide the name and its spacing, for example in a one-to-one channel where
    /// the name adds nothing. Capture the channel from the code that builds the screen to decide.
    ///
    /// It applies around the default bubble and around `messageContent(_:)`, but not around
    /// `messageRow(_:)` or system messages. Your own messages never show a name.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageSenderName { message, _ in
    ///         if channel.memberCount != 2, let name = message.sender?.name {
    ///             Text(name).font(.caption).foregroundStyle(.secondary)
    ///         }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageSenderName(
        @ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.messageSenderName = { AnyView(content($0, $1)) }
        return copy
    }

    /// Adds a custom time beside a message bubble, keeping the rest of the row.
    ///
    /// The default layout omits per-message times. The closure is called on the last message of a run, once it is
    /// sent, on both sides. Pending and failed messages show their sending status there instead,
    /// so the closure is not called for them. The view sits beside the bubble, aligned to its
    /// bottom. Receipts remain beneath your own bubbles. The theme's `timeFont`
    /// and `timeText` are not applied; read `channelTheme` from the environment to use them.
    ///
    /// Format `message.createdAt` yourself. A locale-aware style such as
    /// `.dateTime.hour().minute()` reads "3:05 PM" or "15:05" depending on the locale.
    ///
    /// Return nothing to hide the time and its spacing.
    ///
    /// It applies around the default bubble and around `messageContent(_:)`, but not around
    /// `messageRow(_:)` or system messages. Date separators do not change; see
    /// `messageDateSeparator(_:)`.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageTime { message, _ in
    ///         Text(message.createdAt, format: .dateTime.hour().minute())
    ///             .font(.caption2)
    ///             .foregroundStyle(.secondary)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageTime(@ViewBuilder _ content: @escaping (ChatMessage, MessageRowContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageTime = { AnyView(content($0, $1)) }
        return copy
    }

    /// Replaces the date separator above the first message of each day, or hides it.
    ///
    /// The context carries the date of the day's first message and the default separator's
    /// texts, `day` ("Today", "Yesterday", "Wed, Nov 15") and `time` ("10:13 PM"), so you can
    /// restyle them without formatting the date again. Format `context.date` yourself for other
    /// wording or another locale. The view is centered in the row. The theme's
    /// `dateSeparatorFont`, `dateSeparatorText`, and `dateSeparatorBackground` are not applied;
    /// read `channelTheme` from the environment to use them.
    ///
    /// Return nothing to hide the separator and its spacing. Which messages start a day does not
    /// change, and the separator stays above `messageRow(_:)` too.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageDateSeparator { context in
    ///         Text(context.day.uppercased())
    ///             .font(.caption2.weight(.semibold))
    ///             .foregroundStyle(.secondary)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func messageDateSeparator(
        @ViewBuilder _ content: @escaping (MessageDateSeparatorContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.messageDateSeparator = { AnyView(content($0)) }
        return copy
    }

    /// Sets the composer's placeholder, shown in the empty text field in place of "Enter message".
    ///
    /// Pass text you have already localized. It shows while the user can send and while the
    /// messages load. In a channel that does not allow sending, the field shows "Chat is
    /// unavailable in this channel" instead, which explains why it is disabled.
    ///
    /// - Since: 1.0.0
    func composerPlaceholder(_ text: String) -> Self {
        var copy = self
        copy.slots.composerPlaceholder = text
        return copy
    }

    /// Puts your own views before the composer's text field, such as a camera shortcut, in place
    /// of the attachment (+) button.
    ///
    /// Put `context.defaultItems` in to keep the + button; leave it out to remove it, for example
    /// when your backend does not take attachments. Open the pickers with the `context` actions,
    /// so picked items are sent like the + button's. The items are disabled while
    /// `context.canSend` is `false`, so you do not need to check it. They keep the composer's
    /// spacing and stay aligned with the field's last line as it grows, and they receive the
    /// screen's environment.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerLeadingItems { context in
    ///         if context.canOpenCamera {
    ///             Button { context.openCamera() } label: { Image(systemName: "camera") }
    ///                 .accessibilityLabel("Camera")
    ///         }
    ///         context.defaultItems
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerLeadingItems(@ViewBuilder _ content: @escaping (ComposerContext) -> some View) -> Self {
        var copy = self
        copy.slots.composerLeadingItems = { AnyView(content($0)) }
        return copy
    }

    /// Puts your own views after the composer's text field, inside its background, such as a voice button.
    ///
    /// They show while the field is empty; the send button takes their place while there is text
    /// to send, and the stop button while `composerStopButton(isResponding:action:)` reports a response. There
    /// is no default item on this side, so `context.defaultItems` is empty. The
    /// items are disabled while `context.canSend` is `false`, keep the composer's spacing, and
    /// receive the screen's environment.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerTrailingItems { context in
    ///         Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
    ///             .accessibilityLabel("Photo library")
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerTrailingItems(@ViewBuilder _ content: @escaping (ComposerContext) -> some View) -> Self {
        var copy = self
        copy.slots.composerTrailingItems = { AnyView(content($0)) }
        return copy
    }

    /// Moves the composer's leading items into the text field's background, so the controls and
    /// the field read as one capsule, such as a camera button at the front of the field.
    ///
    /// The default layout keeps the leading items or attachment (+) button outside the field;
    /// trailing items and the send button are already inside. This modifier also brings the
    /// leading controls inside and gives every item a common minimum frame. Each item
    /// sits in a frame of at least 32 × 32pt, centred, so a plain SF Symbol button lines up with
    /// the + and send buttons. The capsule keeps `ChannelTheme.composerFieldBackground` and grows
    /// with the field's lines, with the items on the last line. A side whose items draw nothing,
    /// such as a camera button on a device without a camera, keeps the field's padding. It has no
    /// effect alongside `composer(_:)`.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerItemsInsideField()
    ///     .composerLeadingItems { context in
    ///         if context.canOpenCamera {
    ///             Button { context.openCamera() } label: { Image(systemName: "camera.fill") }
    ///                 .accessibilityLabel("Camera")
    ///         }
    ///     }
    ///     .composerTrailingItems { context in
    ///         Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
    ///             .accessibilityLabel("Photo library")
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerItemsInsideField() -> Self {
        var copy = self
        copy.slots.composerItemsInsideField = true
        return copy
    }

    /// Replaces what the composer's send button shows, such as the text "Send" in place of the
    /// arrow icon. The screen keeps the button, so tapping it sends the draft as before.
    ///
    /// The label shows where the send button does: while there is text to send, in place of the
    /// trailing items, inside the field's background in both layouts. It sits in a frame
    /// of at least 32 × 32pt, centred, the arrow's size, so text lines up with the other buttons
    /// and stays as easy to tap. The label receives the screen's environment and colours itself:
    /// read `ChannelTheme.composerButtonTint` from `@Environment(\.channelTheme)` to match the
    /// other buttons. VoiceOver reads the label as drawn, so give an icon-only label its own
    /// `.accessibilityLabel`. It has no effect alongside `composer(_:)`.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerSendButtonLabel { SendLabel() }
    ///
    /// struct SendLabel: View {
    ///     @Environment(\.channelTheme) private var theme
    ///
    ///     var body: some View {
    ///         Text("Send")
    ///             .font(.body.weight(.semibold))
    ///             .foregroundStyle(theme.composerButtonTint)
    ///     }
    /// }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerSendButtonLabel(@ViewBuilder _ content: @escaping () -> some View) -> Self {
        var copy = self
        copy.slots.composerSendButtonLabel = { AnyView(content()) }
        return copy
    }

    /// Turns the composer's send button into a stop button while `isResponding` is `true`, such as
    /// while an assistant's answer streams in. Tapping it calls `action`.
    ///
    /// Pass the current value from your own state on every update; the screen does not detect or
    /// store whether a response is in progress. While it is `true`, the stop button sits where the
    /// send button does, in place of the trailing items, whether or not there is a draft. It
    /// works even while `context.canSend` is `false`. The field stays editable and keeps its
    /// draft, so the user can write the next message; the return key adds a new line as before,
    /// and send comes back with the draft once `isResponding` is `false`. `composerSendButtonLabel(_:)`
    /// does not change the stop button. VoiceOver reads it as "Stop".
    ///
    /// `ComposerContext.isResponding` and `ComposerContext.stop()` carry the same state and
    /// action. Composer items are replaced by the stop button while it shows, so for a stop button
    /// that looks different, draw the composer with `composer(_:)`, which has no default stop
    /// button, from those two.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerStopButton(isResponding: assistant.isAnswering(channelID: channel.id)) {
    ///         assistant.stopAnswering(channelID: channel.id)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerStopButton(isResponding: Bool, action: @escaping () -> Void) -> Self {
        var copy = self
        copy.slots.composerStopButton = ChannelSlots.ComposerStopButton(isResponding: isResponding, action: action)
        return copy
    }

    /// Replaces the whole composer with your own view, such as an AI agent's composer with a stop
    /// button.
    ///
    /// Your view owns the draft and every control, so `composerPlaceholder(_:)`,
    /// `composerLeadingItems(_:)`, `composerTrailingItems(_:)`, `composerItemsInsideField()`, and
    /// `composerSendButtonLabel(_:)` have no effect alongside it, and
    /// `context.defaultItems` is empty. Send with `context.send(text:)` and clear your draft only
    /// while `context.canSend` is `true`, since the call does nothing otherwise. Open the pickers
    /// with the `context` actions. The screen does not disable your view: read `context.canSend`
    /// to disable what should wait, and `context.isUnavailable` to explain why. To stop a streamed
    /// answer, set `composerStopButton(isResponding:action:)` and draw your stop button from
    /// `context.isResponding` and `context.stop()`; it keeps working because the screen leaves your
    /// view enabled.
    ///
    /// The screen still places your view above the keyboard, so it follows the keyboard as the
    /// user drags the list to dismiss it. It paints `ChannelTheme.composerBackground`, or your
    /// `composerBackground(_:)` view, behind your view down to the screen's bottom edge, keeps the
    /// messages above it, shows the frozen banner, and scrolls to the newest message after a send.
    /// It also shows the reply bar above your view while the user answers a message; hide it with
    /// `composerReplyBar(_:)` if your view draws its own from `context.replyingTo`. Your view
    /// receives the screen's environment.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composer { context in
    ///         AgentComposer(context: context)
    ///     }
    ///
    /// struct AgentComposer: View {
    ///     let context: ComposerContext
    ///     @State private var draft = ""
    ///
    ///     var body: some View {
    ///         HStack {
    ///             TextField("Ask anything", text: $draft)
    ///                 .disabled(!context.canSend)
    ///             Button("Send") {
    ///                 guard context.canSend else { return }
    ///                 context.send(text: draft)
    ///                 draft = ""
    ///             }
    ///             .disabled(!context.canSend)
    ///         }
    ///         .padding()
    ///     }
    /// }
    /// ```
    ///
    /// - Since: 1.0.0
    func composer(@ViewBuilder _ content: @escaping (ComposerContext) -> some View) -> Self {
        var copy = self
        copy.slots.composer = { AnyView(content($0)) }
        return copy
    }

    /// Replaces the bar above the composer that shows which message the user is answering.
    ///
    /// It is called while a reply is being written, which needs `ChatChannel.canReply` to be
    /// `true`, with the message being answered and the composer's context; `context.cancelReply()` closes the bar and keeps the draft. The default
    /// shows "Replying to" and the sender's name, a one-line preview of the message, and a close
    /// button. Return nothing to hide it, for example when your `composer(_:)` view draws its own
    /// from `context.replyingTo`. The bar sits directly above the composer, moves with the
    /// keyboard, and the messages stay above it. Your view receives the screen's environment;
    /// read `channelTheme` from it to match the default.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerReplyBar { message, context in
    ///         HStack {
    ///             Text("Answering \(message.sender?.name ?? "message")")
    ///             Spacer()
    ///             Button("Cancel") { context.cancelReply() }
    ///         }
    ///         .padding(.horizontal)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func composerReplyBar(@ViewBuilder _ content: @escaping (ChatMessage, ComposerContext) -> some View) -> Self {
        var copy = self
        copy.slots.composerReplyBar = { AnyView(content($0, $1)) }
        return copy
    }

    /// Draws your own view behind the composer in place of the `ChannelTheme.composerBackground`
    /// color, such as a gradient that fades the messages out under a floating composer.
    ///
    /// The view is laid out from the composer's top edge down to the bottom edge of the screen,
    /// and sits behind the composer and the reply bar. The area also spans the home indicator, or
    /// the space behind the keyboard while it is up, so its height changes with the keyboard and
    /// a gradient's proportional stops move with it. Messages scroll behind it, so fade them out
    /// with a gradient of fixed height at the top over a solid fill, and give your composer some
    /// top padding for the fade to show in. Your view's buttons do not receive taps. It works with
    /// the default composer and with `composer(_:)` alike, and receives the screen's environment.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .composerBackground {
    ///         VStack(spacing: 0) {
    ///             LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
    ///                 .frame(height: 32)
    ///             Rectangle().fill(.white)
    ///         }
    ///     }
    /// ```
    ///
    /// Without this modifier the screen paints `ChannelTheme.composerBackground` over the same area.
    ///
    /// - Since: 1.0.0
    func composerBackground(@ViewBuilder _ content: @escaping () -> some View) -> Self {
        var copy = self
        copy.slots.composerBackground = { AnyView(content()) }
        return copy
    }

    /// Replaces the round button that returns to the newest message while the user has scrolled up.
    ///
    /// By default, a 44pt glass button with a down arrow floats above the composer whenever the
    /// newest message is more than 100 points below the visible part of the list, including
    /// after new messages arrive while the user reads older ones. Tapping it scrolls to the newest
    /// message, and the list follows new messages again. VoiceOver reads it as "Jump to latest".
    ///
    /// The closure receives `jump`, the action that scrolls to the newest message. Call it from
    /// your button. The screen still decides when the view shows, fades and scales it in and out,
    /// and places it centered just above the composer and the reply bar, moving with the
    /// keyboard. Return no view to hide the button. Your view receives the screen's environment;
    /// read `channelTheme` from it to match the default, and label an icon-only button for
    /// VoiceOver yourself.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .jumpToLatestButton { jump in
    ///         Button(action: jump) {
    ///             Label("Latest", systemImage: "arrow.down")
    ///                 .padding(.horizontal, 14)
    ///                 .padding(.vertical, 8)
    ///                 .background(.thinMaterial, in: Capsule())
    ///         }
    ///         .buttonStyle(.plain)
    ///     }
    ///
    /// // Or hide it:
    /// ChannelView(channel: channel)
    ///     .jumpToLatestButton { _ in EmptyView() }
    /// ```
    ///
    /// - Since: 1.0.0
    func jumpToLatestButton(@ViewBuilder _ content: @escaping (_ jump: @escaping () -> Void) -> some View) -> Self {
        var copy = self
        copy.slots.jumpToLatestButton = { AnyView(content($0)) }
        return copy
    }

    /// Chooses how the message list moves when the user sends a message.
    ///
    /// By default (`.followsLatest`) the list scrolls to the newest message and follows the reply
    /// as it grows, as in a messenger. With `.questionToTop` the sent message moves to the top of
    /// the list instead, 16 points below the header, and the reply fills the space below it, as in
    /// an AI chat. The list adds blank space below the messages so the sent message can reach the
    /// top even when the channel is short; the space shrinks as the reply grows and is gone once
    /// the reply reaches the bottom of the screen. From then on the list stays where it is while
    /// the reply keeps growing, and the jump-to-latest button shows once the reply's end is out of
    /// view. Scrolling, the keyboard, and older pages keep the sent message where it is.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageScrollBehavior(.questionToTop)
    /// ```
    ///
    /// The move applies to messages sent from the composer, including `ComposerContext.send(text:)`
    /// from your own views. Your backend must put a sent message in the next snapshot as pending,
    /// as the adapter rules already require; the list moves the first new pending message of the
    /// current user's that arrives after the send.
    ///
    /// - Since: 1.0.0
    func messageScrollBehavior(_ behavior: MessageScrollBehavior) -> Self {
        var copy = self
        copy.slots.scrollBehavior = behavior
        return copy
    }

    /// Called when a default image, video, or file attachment is tapped, with the message that
    /// carries it.
    ///
    /// The screen does not open, download, or preview attachments itself. Without this callback,
    /// attachments are not buttons. It is not called for a message that is still sending or failed:
    /// its file is not on the backend yet, and tapping a failed message opens its dialog.
    /// Custom message slots handle their own taps.
    ///
    /// - Since: 1.0.0
    func onAttachmentSelected(_ action: @escaping (ChatAttachment, ChatMessage) -> Void) -> Self {
        var copy = self
        copy.slots.attachmentSelected = action
        return copy
    }

    /// Sets the menu a user message shows when long-pressed.
    ///
    /// A long press on the bubble opens it, and the menu lifts the bubble alone. A row drawn by
    /// `messageRow(_:)` is lifted whole, because the screen does not know where its bubble is.
    ///
    /// Return plain `Button`s with text labels, as in `.contextMenu`. Put `context.defaultItems`
    /// in to keep the screen's own buttons, fitted to the message: Retry (while the user can send)
    /// and Remove for a failed message; for any other message, Reply (while `context.canReply`)
    /// and Copy (when it has text). Leave it out to decide every button yourself. Returning no buttons shows no menu. System messages are not
    /// passed here.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageContextMenu { message, context in
    ///         context.defaultItems
    ///         Button("Report") { report(message) }
    ///     }
    /// ```
    ///
    /// Without this modifier the menu holds only the default buttons. It does not change what
    /// tapping a failed message shows; that is `failedMessageActions(_:)`.
    ///
    /// `messageLongPressOverlay(above:below:)` replaces this menu: while it is set, a long press
    /// shows the overlay and this modifier has no effect, whatever their order.
    ///
    /// - Since: 1.0.0
    func messageContextMenu(@ViewBuilder _ content: @escaping (ChatMessage, MessageActionContext) -> some View) -> Self {
        var copy = self
        copy.slots.messageContextMenu = { AnyView(content($0, $1)) }
        return copy
    }

    /// Shows your own views above and below a long-pressed message in place of the system menu;
    /// your buttons must call `context.dismiss()` when they finish, because the overlay stays
    /// open until something closes it.
    ///
    /// A long press on a user message's bubble lifts it, dims the messages and the composer, and
    /// places the `above:` view above the bubble and the `below:` view below it, both on the
    /// sender's side. The screen draws a card around the `below:` view and gives its buttons the
    /// card's row style, so `context.defaultItems` (Retry and Remove for a failed message; Reply
    /// and Copy otherwise) and your own `Button`s look the same; a button with its own
    /// `.buttonStyle` keeps it. The `above:` view is placed as it is, such as a bar of reactions.
    /// The default items close the overlay after acting; tapping the dimmed area closes it too.
    ///
    /// Both closures are always written; return nothing from one to leave its side empty. When
    /// both return nothing for a message, a long press on it does nothing. The navigation bar
    /// stays undimmed, and the keyboard stays up. System messages are not passed here.
    ///
    /// The lifted bubble is drawn again from the same message: the default bubble, the
    /// `messageContent(_:)` slot's view, or the whole `messageRow(_:)` slot's row. A slot's
    /// view-local `@State` starts fresh in that copy.
    ///
    /// Reactions stay with your backend: picking one calls your code, and
    /// `messageAccessory(_:)` draws them below the bubble. A pending or failed message is not on
    /// the backend yet, so check `message.sendingStatus` before offering actions that need it.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .messageLongPressOverlay { message, context in
    ///         if message.sendingStatus == nil {
    ///             EmojiBar { emoji in
    ///                 react(to: message, with: emoji)
    ///                 context.dismiss()
    ///             }
    ///         }
    ///     } below: { message, context in
    ///         context.defaultItems
    ///         Button("Report") {
    ///             report(message)
    ///             context.dismiss()
    ///         }
    ///     }
    /// ```
    ///
    /// While this is set, `messageContextMenu(_:)` has no effect. It does not change what
    /// tapping a failed message shows; that is `failedMessageActions(_:)`.
    ///
    /// - Since: 1.0.0
    func messageLongPressOverlay(
        @ViewBuilder above: @escaping (ChatMessage, MessageOverlayContext) -> some View,
        @ViewBuilder below: @escaping (ChatMessage, MessageOverlayContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.messageLongPressOverlay = .init(
            above: { AnyView(above($0, $1)) },
            below: { AnyView(below($0, $1)) }
        )
        return copy
    }

    /// Sets the confirmation dialog a message shows when tapped after it failed to send.
    ///
    /// Return plain `Button`s with text labels; the dialog shows only their titles and roles, adds
    /// Cancel, and a button with an icon appears there as two accessibility elements.
    /// `context.defaultItems` holds Retry (while the user can send) and Remove. Leave out
    /// `context.resend()` and `context.remove()` here and in `messageContextMenu(_:)` and the
    /// user has no way to recover the message. Returning no buttons makes the tap do nothing.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .failedMessageActions { message, context in
    ///         context.defaultItems
    ///         Button("Edit and Resend") { edit(message) }
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func failedMessageActions(@ViewBuilder _ content: @escaping (ChatMessage, MessageActionContext) -> some View) -> Self {
        var copy = self
        copy.slots.failedMessageActions = { AnyView(content($0, $1)) }
        return copy
    }

    /// Called when a message is double-tapped, with that message and a `MessageActionContext`,
    /// for example to send a reaction through your own backend.
    ///
    /// It shows nothing itself; act in the closure. It is called whatever the message's
    /// `sendingStatus`; a pending or failed message is not on the backend yet, so check it before
    /// acting there. Double taps are recognized only while this is set, because recognizing them
    /// makes a single tap on a failed message wait briefly. Buttons inside the row, such as default
    /// attachments and a slot's own controls, take their taps first. System messages are not
    /// passed here.
    ///
    /// ```swift
    /// ChannelView(channel: channel)
    ///     .onMessageDoubleTapped { message, context in
    ///         guard message.sendingStatus == nil else { return }
    ///         react(to: message)
    ///     }
    /// ```
    ///
    /// - Since: 1.0.0
    func onMessageDoubleTapped(_ action: @escaping (ChatMessage, MessageActionContext) -> Void) -> Self {
        var copy = self
        copy.slots.messageDoubleTapped = action
        return copy
    }

    /// Replaces the whole row of messages carrying the given custom value type.
    ///
    /// Other types use their own renderer, the untyped row slot, or the default row. The last
    /// registration for this type wins. Date separators and pagination remain outside the slot.
    ///
    /// The message signals still work around whatever the slot draws: a long press opens the
    /// menu, which lifts the whole slot view, and tapping a failed message opens its dialog (by default Retry and Remove). Buttons
    /// and tap gestures inside the slot get the tap first, so a tap gesture that covers the whole
    /// slot hides that dialog; leave it off while `message.sendingStatus` is `.failed`. Declare
    /// menu items with `messageContextMenu(_:)` rather than a `.contextMenu` inside the slot. Use
    /// `message.sendingStatus` to show the pending and failed states.
    ///
    /// `messageLongPressOverlay(above:below:)` lifts a new copy of the whole row, unscaled, in
    /// which view-local `@State` starts fresh. Keep state that must survive it in the message or
    /// your own model.
    ///
    /// - Since: 1.0.0
    func messageRow<Value: Hashable & Sendable>(
        _ type: Value.Type,
        @ViewBuilder _ content: @escaping (Value, ChatMessage, MessageRowContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.customMessageRows.append { message, context in
            guard let value = message.customContent?.value(as: type) else { return nil }
            return AnyView(content(value, message, context))
        }
        return copy
    }

    /// Replaces the bubble content of messages carrying the given custom value type.
    ///
    /// Keeps the default sender, time, and receipt layout. Other types use their own renderer,
    /// the untyped content slot, or the default content. The last registration for this type wins.
    /// System messages use the whole-row slot instead.
    ///
    /// A long press on the slot's view still opens the message menu, which lifts that view alone.
    /// Declare menu items with `messageContextMenu(_:)` rather than a `.contextMenu` inside the
    /// slot, which would compete with it.
    ///
    /// `messageLongPressOverlay(above:below:)` lifts a new copy of the slot's view, in which
    /// view-local `@State` starts fresh. Keep state that must survive it in the message or your
    /// own model.
    ///
    /// - Since: 1.0.0
    func messageContent<Value: Hashable & Sendable>(
        _ type: Value.Type,
        @ViewBuilder _ content: @escaping (Value, ChatMessage, MessageRowContext) -> some View
    ) -> Self {
        var copy = self
        copy.slots.customMessageContents.append { message, context in
            guard let value = message.customContent?.value(as: type) else { return nil }
            return AnyView(content(value, message, context))
        }
        return copy
    }
}
