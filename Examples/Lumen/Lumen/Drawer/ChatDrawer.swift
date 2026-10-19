import SwiftUI
import AnyChatUI

/// Past chats, newest first, with a button for a new one. Swipe a chat to delete it.
struct ChatDrawer: View {
    let selectedChannelID: String?
    let onNewChat: () -> Void
    let onSelect: (ChatChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                LumenMark()
                    .stroke(LumenStyle.ink, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("Lumen")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LumenStyle.ink)
                Spacer()
                Button(action: onNewChat) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 19))
                        .foregroundStyle(LumenStyle.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("New chat")
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)

            Text("Chats")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LumenStyle.secondaryInk)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ChannelListView()
                .channelRow { channel in
                    Text(channel.name ?? "New chat")
                        .font(.system(size: 17))
                        .foregroundStyle(LumenStyle.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background {
                            if channel.id == selectedChannelID {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LumenStyle.userBubble)
                            }
                        }
                        .padding(.horizontal, 12)
                }
                .onChannelSelected(onSelect)

            HStack(spacing: 12) {
                Text("JP")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(red: 0.36, green: 0.42, blue: 0.94)))
                    .accessibilityHidden(true)
                Text(LumenBackend.me.name ?? "")
                    .font(.system(size: 17))
                    .foregroundStyle(LumenStyle.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .padding(.top, 8)
        .background(LumenStyle.background)
    }
}
