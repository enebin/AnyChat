import SwiftUI
import AnyChatUI

struct ChatScreen: View {
    let channel: ChatChannel
    let backend: LumenBackend
    let onOpenDrawer: () -> Void
    let onNewChat: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ChannelView(channel: channel)
            .channelHeader { _ in EmptyView() }
            .messageRow(Answer.self) { answer, message, _ in
                AnswerRow(
                    answer: answer,
                    message: message,
                    onFeedback: { backend.setFeedback($0, messageID: message.id, channelID: channel.id) },
                    onRegenerate: { backend.regenerate(messageID: message.id, channelID: channel.id) }
                )
            }
            .messageBubbleLayout(insets: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .messageBubbleBackground { _, _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LumenStyle.userBubble)
            }
            .messageTime { _, _ in EmptyView() }
            .messageDateSeparator { _ in EmptyView() }
            .messageScrollBehavior(.questionToTop)
            .composerStopButton(isResponding: backend.isGenerating(channelID: channel.id)) {
                backend.stop(channelID: channel.id)
            }
            .channelEmptyState { composer in
                Suggestions { composer.send(text: $0) }
                    .disabled(!composer.canSend)
            }
            .composer { ChatComposer(context: $0, backend: backend) }
            .composerBackground { ComposerFade() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DrawerButton(action: onOpenDrawer)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onNewChat) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New chat")
                    Menu {
                        Button("Delete chat", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
    }
}

/// Lumen keeps its own bar rather than the default composer: it has a tool chip, a floating card,
/// and a voice button the default lacks.
/// It reads the backend in its own body, so the hosted composer redraws when the tool changes.
private struct ChatComposer: View {
    let context: ComposerContext
    @Bindable var backend: LumenBackend

    var body: some View {
        ComposerBar(
            context: context,
            isGenerating: context.isResponding,
            mode: $backend.selectedMode,
            onStop: context.stop
        )
    }
}

/// A fixed-height fade over the composer's top padding rather than gradient stops: the area also
/// spans the home indicator while the keyboard is down, which would stretch the stops.
private struct ComposerFade: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [LumenStyle.background.opacity(0), LumenStyle.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
            LumenStyle.background
        }
    }
}

struct DrawerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(LumenStyle.ink)
        }
        .accessibilityLabel("Open chats")
    }
}
