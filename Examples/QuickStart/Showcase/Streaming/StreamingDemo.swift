import SwiftUI
import AnyChatUI

/// The repository sends text that grows in place, and a slot animates it. The model has no
/// "streaming" flag, so the slot only knows that the same message id now has longer text.
struct StreamingDemo: View {
    private static let replyWordInterval: Duration = .milliseconds(150)

    @State private var backend = SampleChatBackend()
    /// Held here rather than made by the backend, so the demo can push updates into it.
    @State private var repository = SampleChannelListRepository(channels: SampleData.channels(now: Date()))
    @State private var isReplying = false
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        ChannelListView(repository: repository, currentUserID: SampleChatBackend.currentUserID)
            .channelPreview { channel in
                PreviewLine(message: channel.lastMessage)
            }
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Streaming")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Start reply") { isReplying = true }
                        .disabled(isReplying)
                }
            }
            // Leaving the list, by going back or opening a channel, cancels the reply.
            .task(id: isReplying) {
                guard isReplying else {
                    return
                }
                await streamReply()
                isReplying = false
            }
            // A pushed view takes its environment from the stack, which sits above this demo.
            .navigationDestination(item: $selectedChannel) { channel in
                channelScreen(channel)
                    .chatBackend(backend)
            }
    }

    /// Grows a new reply in the assistant channel one word at a time, keeping its id.
    private func streamReply() async {
        let id = UUID().uuidString
        let createdAt = Date()
        let words = SampleData.streamedReplyText.split(separator: " ")
        for count in 1...words.count {
            let reply = ChatMessage(
                id: id,
                sender: SampleData.assistant,
                createdAt: createdAt,
                content: .text(words.prefix(count).joined(separator: " "))
            )
            repository.updateChannel(id: SampleData.assistantChannelID) { $0.lastMessage = reply }
            do {
                try await Task.sleep(for: Self.replyWordInterval)
            } catch {
                return
            }
        }
    }

    private func channelScreen(_ channel: ChatChannel) -> ChannelView {
        let screen = ChannelView(channel: channel)
        // Only this channel streams. A content slot replaces every bubble, attachments included.
        guard channel.id == SampleData.assistantChannelID else {
            return screen
        }
        return screen.messageContent { message, context in
            TypewriterBubble(message: message, isMine: context.isMine)
        }
    }
}

private struct PreviewLine: View {
    let message: ChatMessage?

    @Environment(\.channelListTheme) private var theme

    var body: some View {
        TypewriterText(id: message?.id ?? "", text: message?.summary ?? "")
            .font(theme.messageFont)
            .foregroundStyle(theme.messageText)
            .lineLimit(2)
    }
}

private struct TypewriterBubble: View {
    let message: ChatMessage
    let isMine: Bool

    @Environment(\.channelTheme) private var theme

    var body: some View {
        TypewriterText(id: message.id, text: message.summary)
            .font(theme.messageFont)
            .foregroundStyle(isMine ? theme.outgoingMessageText : theme.incomingMessageText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isMine ? theme.outgoingBubbleBackground : theme.incomingBubbleBackground)
            )
    }
}

/// Types out the part of `text` it has not shown yet.
///
/// The first text a view shows appears at once, so rows that are not streaming do not animate.
/// A new `id` starts over from an empty line.
private struct TypewriterText: View {
    private static let characterInterval: Duration = .milliseconds(20)

    let id: String
    let text: String

    @State private var shownID: String?
    @State private var shownCount = 0

    var body: some View {
        Text(visibleText)
            .task(id: [id, text]) {
                await typeOut()
            }
    }

    private var visibleText: String {
        switch shownID {
        case nil: text
        case id: String(text.prefix(shownCount))
        default: ""
        }
    }

    private func typeOut() async {
        guard let shownID else {
            self.shownID = id
            shownCount = text.count
            return
        }
        if shownID != id {
            self.shownID = id
            shownCount = 0
        }
        shownCount = min(shownCount, text.count)
        while shownCount < text.count {
            do {
                try await Task.sleep(for: Self.characterInterval)
            } catch {
                return
            }
            shownCount += 1
        }
    }
}

private extension ChatMessage {
    /// One line of text for a slot that replaces the default message or preview text.
    var summary: String {
        switch content {
        case .text(let text) where !text.isEmpty: text
        case .text, .files: attachments.count == 1 ? "1 attachment" : "\(attachments.count) attachments"
        case .system(let text): text
        case .file(.voice): "Voice message"
        case .file: "File"
        case .unsupported: "Unsupported message"
        }
    }
}
