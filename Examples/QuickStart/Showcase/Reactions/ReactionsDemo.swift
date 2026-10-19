import SwiftUI
import AnyChatUI

/// Replaces the long-press menu with an emoji bar above the lifted bubble and the default actions
/// plus a Report button below it, and draws the picked reactions under each bubble.
struct ReactionsDemo: View {
    @State private var backend = SampleChatBackend()
    @State private var selectedChannel: ChatChannel?
    /// Kept by the demo rather than sent anywhere; an app sends a reaction through its backend.
    @State private var reactions: [String: [String]] = [:]
    @State private var reportedText: String?

    var body: some View {
        ChannelListView()
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Reactions")
            .navigationDestination(item: $selectedChannel) { channel in
                channelScreen(channel)
                    .chatBackend(backend)
                    .alert("Reported", isPresented: showsReport) {
                        Button("OK") { reportedText = nil }
                    } message: {
                        Text(reportedText ?? "")
                    }
            }
            .chatBackend(backend)
    }

    private func channelScreen(_ channel: ChatChannel) -> ChannelView {
        ChannelView(channel: channel)
            .messageLongPressOverlay { message, context in
                // A pending or failed message is not on the backend yet, so it takes no reaction.
                if message.sendingStatus == nil {
                    EmojiBar { emoji in
                        reactions[message.id, default: []].append(emoji)
                        context.dismiss()
                    }
                }
            } below: { message, context in
                context.defaultItems
                if !context.isMine {
                    Button("Report", role: .destructive) {
                        reportedText = message.summary
                        context.dismiss()
                    }
                }
            }
            .messageAccessory { message, _ in
                if let picked = reactions[message.id], !picked.isEmpty {
                    Text(picked.joined())
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
    }

    private var showsReport: Binding<Bool> {
        Binding(get: { reportedText != nil }, set: { if !$0 { reportedText = nil } })
    }
}

private struct EmojiBar: View {
    let onPick: (String) -> Void

    private let emojis = ["❤️", "👍", "👎", "😂", "‼️", "❓"]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(emojis, id: \.self) { emoji in
                Button(emoji) { onPick(emoji) }
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

private extension ChatMessage {
    var summary: String {
        if case let .text(text) = content { return text }
        return "a message"
    }
}
