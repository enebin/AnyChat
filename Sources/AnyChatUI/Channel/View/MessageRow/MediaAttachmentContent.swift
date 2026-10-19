import AnyChatCore
import SwiftUI

/// A message's only image, GIF, or video.
struct MediaAttachmentContent: View {
    let attachment: ChatAttachment

    private static let width: CGFloat = 240
    private static let height: CGFloat = 160
    private static let cornerRadius: CGFloat = 16
    private static let metrics = MediaThumbnail.Metrics(placeholderIconSize: 48, badgeSize: 48, badgeIconSize: 28)

    var body: some View {
        MediaThumbnail(attachment: attachment, metrics: Self.metrics)
            .frame(width: Self.width, height: Self.height)
            .clipShape(.rect(cornerRadius: Self.cornerRadius))
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
    }
}
