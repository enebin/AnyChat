import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// A non-media attachment: its kind's icon and its file name in a message bubble.
struct FileAttachmentContent: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @Environment(\.channelTheme) private var theme

    private static let maxWidth: CGFloat = 240
    private static let height: CGFloat = 44
    private static let cornerRadius: CGFloat = 16
    private static let horizontalPadding: CGFloat = 12
    private static let spacing: CGFloat = 8
    private static let iconTileSize: CGFloat = 28
    private static let iconTileCornerRadius: CGFloat = 8
    private static let iconSize: CGFloat = 24

    var body: some View {
        BubbleWidthLimit(maxWidth: Self.maxWidth) {
            HStack(spacing: Self.spacing) {
                icon
                    .sized(Self.iconSize)
                    .foregroundStyle(theme.fileIconTint)
                    .frame(width: Self.iconTileSize, height: Self.iconTileSize)
                    .background(theme.fileIconBackground, in: .rect(cornerRadius: Self.iconTileCornerRadius))
                Text(attachment.fileName ?? attachment.url.lastPathComponent)
                    .font(theme.messageFont)
                    .foregroundStyle(isMine ? theme.outgoingMessageText : theme.incomingMessageText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.height)
            .background(
                isMine ? theme.outgoingBubbleBackground : theme.incomingBubbleBackground,
                in: .rect(cornerRadius: Self.cornerRadius)
            )
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
        }
    }

    private var icon: ChatIcon {
        switch attachment.kind {
        case .audio, .voice: .fileAudio
        case .image, .gif, .video, .other: .fileDocument
        }
    }
}
