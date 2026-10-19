import SwiftUI
import AnyChatUI

/// Puts the composer's buttons inside the text field as one capsule with a "Send" text button,
/// or replaces the whole composer with a pill-shaped one that owns its draft and controls over a
/// fade down to the screen edge, while the screen keeps it above the keyboard.
struct ComposerDemo: View {
    @State private var backend = SampleChatBackend()
    @State private var mode = ComposerMode.capsule
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        ChannelListView()
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Composer")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Composer", selection: $mode) {
                        ForEach(ComposerMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationDestination(item: $selectedChannel) { channel in
                channelScreen(channel)
                    .chatBackend(backend)
            }
            .chatBackend(backend)
    }

    private func channelScreen(_ channel: ChatChannel) -> ChannelView {
        let screen = ChannelView(channel: channel)
        switch mode {
        case .capsule:
            return screen
                .composerItemsInsideField()
                .composerLeadingItems { context in
                    if context.canOpenCamera {
                        Button { context.openCamera() } label: { Image(systemName: "camera.fill") }
                            .accessibilityLabel("Camera")
                    }
                    context.defaultItems
                }
                .composerTrailingItems { context in
                    Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
                        .accessibilityLabel("Photo library")
                }
                .composerSendButtonLabel { SendLabel() }
        case .whole:
            return screen
                .composer { context in
                    PillComposer(context: context)
                }
                .composerBackground { FadeBackground() }
        }
    }
}

private struct SendLabel: View {
    @Environment(\.channelTheme) private var theme

    var body: some View {
        Text("Send")
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.composerButtonTint)
    }
}

private struct FadeBackground: View {
    @Environment(\.channelTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [theme.background.opacity(0), theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            Rectangle().fill(theme.background)
        }
    }
}

private enum ComposerMode: CaseIterable {
    case capsule
    case whole

    var title: String {
        switch self {
        case .capsule: "Capsule"
        case .whole: "Whole"
        }
    }
}

private struct PillComposer: View {
    let context: ComposerContext

    @State private var draft = ""
    @Environment(\.channelTheme) private var theme

    private var placeholder: String {
        context.isUnavailable ? "Chat is unavailable in this channel" : "Write a message"
    }

    private var canSendDraft: Bool {
        context.canSend && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { context.openAttachmentMenu() } label: {
                Image(systemName: "paperclip")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Attach")

            TextField(placeholder, text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.vertical, 6)

            Button {
                guard canSendDraft else { return }
                context.send(text: draft)
                draft = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(canSendDraft ? theme.composerButtonTint : theme.composerDisabledTint))
            }
            .disabled(!canSendDraft)
            .accessibilityLabel("Send")
        }
        .tint(theme.composerButtonTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().strokeBorder(.quaternary))
        .disabled(!context.canSend)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
