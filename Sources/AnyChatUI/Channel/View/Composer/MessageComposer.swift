import AnyChatDesignSystem
import SwiftUI

/// The bar below the messages: an add button or the host's leading items, the text field, and a
/// stop button while the host reports a response, a send button while there is text to send,
/// otherwise the host's trailing items. With
/// `itemsInsideField`, the field's background holds the items too, as one capsule.
///
/// The draft lives here: no transition depends on it, and sending each keystroke through the
/// Store would redraw the screen for nothing.
struct MessageComposer: View {
    let presentation: ComposerPresentation
    let leadingContext: ComposerContext
    let trailingContext: ComposerContext

    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let spacing: CGFloat = 12
    static let sidePadding: CGFloat = 28
    static let keyboardSidePadding: CGFloat = 16
    private let fieldLineHeight: CGFloat = 19
    static let verticalPadding: CGFloat = 10
    private let buttonBottomPadding: CGFloat = 0
    private let fieldMinHeight: CGFloat = 43
    private let fieldHorizontalPadding: CGFloat = 16
    private let fieldVerticalPadding: CGFloat = 8
    private let maxLines = 5
    private let capsuleBarPadding: CGFloat = 12
    private let capsuleEdgeInset: CGFloat = 2
    private let capsuleItemSide: CGFloat = 32
    private let sendButtonSide: CGFloat = 32

    private var theme: ChannelTheme { presentation.theme }

    /// Narrows from 28pt to 16pt as the keyboard rises. `ComposerRoot` applies it around the
    /// default bar and the reply bar together, so a bar that appears mid-animation follows too.
    static func sidePadding(keyboardProgress: CGFloat) -> CGFloat {
        sidePadding - (sidePadding - keyboardSidePadding) * keyboardProgress
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The design source's 19pt lines fit only its 16pt font. A host font or a larger text size
    /// keeps the font's own line height, so its lines never overlap.
    private var usesDesignLineHeight: Bool {
        theme.composerFont == ChatTypography.composer && dynamicTypeSize == .large
    }

    private var trailingControl: TrailingControl {
        presentation.trailingControl(hasDraft: !trimmedDraft.isEmpty)
    }

    var body: some View {
        Group {
            if presentation.itemsInsideField {
                capsuleBar
            } else {
                bar
            }
        }
        // The whole hosted bar must grow with the field, including its glass and side controls.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bar: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            if let leadingItems = presentation.leadingItems {
                hostItems(leadingItems(leadingContext))
            } else {
                leadingContext.defaultItems
                    .disabled(!presentation.isEnabled)
                    .padding(.bottom, buttonBottomPadding)
            }

            HStack(alignment: .bottom, spacing: 0) {
                field
                switch trailingControl {
                case .stop:
                    stopButton
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                case .send:
                    sendButton
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                case .items:
                    if let trailingItems = presentation.trailingItems {
                        hostItems(trailingItems(trailingContext))
                    }
                }
            }
            .frame(minHeight: fieldMinHeight)
            .modifier(GlassSurface(tint: theme.composerFieldBackground))
        }
        .padding(.vertical, Self.verticalPadding)
        .frame(maxWidth: .infinity)
    }

    private var field: some View {
        textField
            .padding(.horizontal, fieldHorizontalPadding)
            .padding(.vertical, fieldVerticalPadding)
            .frame(minHeight: fieldMinHeight)
            // Without it the hosted composer stays shorter than the wrapped text and scrolls the upper lines away.
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Without `fixedSize` on the field, framed items beside it kept the hosted composer at one
    /// line's height while the text wrapped, so the upper lines were cut off.
    private var capsuleBar: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            Group(subviews: capsuleLeadingItems) { items in
                capsuleSide(items, isHost: presentation.leadingItems != nil, edge: .leading)
            }
            textField
                .padding(.vertical, fieldVerticalPadding)
                .frame(minHeight: fieldMinHeight)
                .fixedSize(horizontal: false, vertical: true)
            Group(subviews: capsuleTrailingItems) { items in
                capsuleSide(items, isHost: trailingControl == .items, edge: .trailing)
            }
        }
        .modifier(GlassSurface(tint: theme.composerFieldBackground))
        .padding(.horizontal, capsuleBarPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(maxWidth: .infinity)
    }

    /// A side has items only when it renders a subview, so a slot that draws nothing, such as a
    /// camera button on a device without one, leaves the field its padding on that side. The
    /// spacer and the edge inset subtract the bar's spacing, which sits between them and the field.
    @ViewBuilder
    private func capsuleSide(_ items: SubviewsCollection, isHost: Bool, edge: HorizontalEdge) -> some View {
        if items.isEmpty {
            Color.clear.frame(width: fieldHorizontalPadding - spacing, height: 0)
        } else {
            let outermost = edge == .leading ? items.first?.id : items.last?.id
            ForEach(items) { item in
                capsuleItem(item, isHost: isHost)
                    .padding(edge == .leading ? .leading : .trailing, item.id == outermost ? capsuleEdgeInset : 0)
            }
        }
    }

    @ViewBuilder
    private var capsuleLeadingItems: some View {
        if let leadingItems = presentation.leadingItems {
            leadingItems(leadingContext)
        } else {
            leadingContext.defaultItems
                .disabled(!presentation.isEnabled)
        }
    }

    @ViewBuilder
    private var capsuleTrailingItems: some View {
        switch trailingControl {
        case .stop:
            stopButton
        case .send:
            sendButton
        case .items:
            if let trailingItems = presentation.trailingItems {
                trailingItems(trailingContext)
            }
        }
    }

    /// A bare SF Symbol button is about 20–24pt; the frame centres it in the capsule's rounded end
    /// as the 32pt icon buttons are. Host items get `hostEnvironment` right around them, as in
    /// `hostItems`; the package's +, send, and stop buttons read only the theme.
    private func capsuleItem(_ item: Subview, isHost: Bool) -> some View {
        Group {
            if isHost {
                item.environment(\.self, hostEnvironment)
            } else {
                item
            }
        }
        .frame(minWidth: capsuleItemSide, minHeight: capsuleItemSide)
        .padding(.bottom, buttonBottomPadding)
    }

    /// A host label gets `hostEnvironment` right around it, as the items do, so it colours itself:
    /// a tint set on the button would not reach through the adopted environment. Its frame sits
    /// inside the button so the tap target is at least the icon button's 32pt.
    @ViewBuilder
    private var sendButton: some View {
        if let label = presentation.sendButtonLabel {
            Button(action: send) {
                label()
                    .environment(\.self, hostEnvironment)
                    .frame(minWidth: sendButtonSide, minHeight: sendButtonSide)
                    .contentShape(Rectangle())
            }
        } else {
            IconButton(.send, tint: theme.composerButtonTint, action: send)
                .accessibilityLabel("Send")
        }
    }

    private var stopButton: some View {
        IconButton(.stop, tint: theme.composerButtonTint, action: presentation.onStop)
            .accessibilityLabel("Stop")
    }

    private var textField: some View {
        TextField(
            "",
            text: $draft,
            prompt: Text(presentation.placeholderText).foregroundStyle(presentation.isEnabled ? theme.composerPlaceholderText : theme.composerDisabledTint),
            axis: .vertical
        )
        .lineLimit(1...maxLines)
        .font(theme.composerFont)
        .modifier(ExactLineHeight(points: usesDesignLineHeight ? fieldLineHeight : nil))
        .foregroundStyle(theme.composerText)
        .tint(theme.composerCursor)
        .focused($isFieldFocused)
        // Starting a reply opens the keyboard, as in messengers.
        .onChange(of: presentation.replyingTo?.id) { _, id in
            if id != nil {
                isFieldFocused = true
            }
        }
        .disabled(!presentation.isEnabled)
        .accessibilityLabel("Message")
    }

    /// The host's items get the screen's environment with `isEnabled` written into the copy. No
    /// `.disabled` sits between that environment and the items: a write there is what once leaked
    /// back into the representable's `isEnabled` and kept the + button disabled.
    private func hostItems(_ items: AnyView) -> some View {
        Group(subviews: items) { subviews in
            ForEach(subviews) { item in
                item.padding(.bottom, buttonBottomPadding)
            }
        }
        .environment(\.self, hostEnvironment)
    }

    private var hostEnvironment: EnvironmentValues {
        var environment = presentation.environment
        environment.isEnabled = presentation.isEnabled
        return environment
    }

    private func send() {
        let text = trimmedDraft
        guard presentation.isEnabled, !text.isEmpty else {
            return
        }
        draft = ""
        presentation.onSend(text)
    }
}

/// Before iOS 26, and without `points`, the field keeps the font's own line height.
private struct ExactLineHeight: ViewModifier {
    let points: CGFloat?

    func body(content: Content) -> some View {
        if #available(iOS 26, *), let points {
            content.lineHeight(.exact(points: points))
        } else {
            content
        }
    }
}
