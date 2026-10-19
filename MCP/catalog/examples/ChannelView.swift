import SwiftUI
import AnyChatUI

// Push it inside your own `NavigationStack` with a channel your app already has,
// such as one selected in `ChannelListView`. A backend registered with `.chatBackend(_:)` above it loads the messages.
struct ChannelScreen: View {
    let channel: ChatChannel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ChannelView(channel: channel)
            .onAttachmentSelected { attachment, _ in
                openURL(attachment.url)
            }
            // Optional: your own views around a long-pressed message in place of the system menu.
            // Buttons you add call `context.dismiss()` when they finish.
            .messageLongPressOverlay { message, context in
                if message.sendingStatus == nil {
                    HStack {
                        ForEach(["❤️", "👍", "😂"], id: \.self) { emoji in
                            Button(emoji) {
                                // Send the reaction through your backend here.
                                context.dismiss()
                            }
                        }
                    }
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                }
            } below: { _, context in
                context.defaultItems
            }
    }
}
