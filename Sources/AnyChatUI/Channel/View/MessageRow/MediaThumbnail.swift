import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// An image, GIF, or video drawn as a still picture, with a badge for the moving kinds.
///
/// Fills whatever frame the caller gives it; the caller clips it.
struct MediaThumbnail: View {
    struct Metrics {
        let placeholderIconSize: CGFloat
        let badgeSize: CGFloat
        let badgeIconSize: CGFloat
    }

    /// The widest thumbnail, 240pt, at 3x. Grid cells use the same length so a picture is
    /// decoded and cached once.
    private static let pixelLength: CGFloat = 720

    let attachment: ChatAttachment
    let metrics: Metrics

    @Environment(\.channelTheme) private var theme

    var body: some View {
        RemoteImage(
            url: attachment.url,
            kind: attachment.kind == .video ? .videoFrame : .image,
            maxPixelLength: Self.pixelLength
        ) {
            ZStack {
                theme.incomingBubbleBackground
                ChatIcon.photo
                    .sized(metrics.placeholderIconSize)
                    .foregroundStyle(theme.mediaPlaceholderTint)
            }
        }
        .overlay {
            if let badge {
                badge
                    .sized(metrics.badgeIconSize)
                    .foregroundStyle(theme.mediaBadgeTint)
                    .frame(width: metrics.badgeSize, height: metrics.badgeSize)
                    .background(theme.mediaBadgeBackground, in: .circle)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(attachment.fileName ?? attachment.url.lastPathComponent)
        .accessibilityAddTraits(.isImage)
    }

    private var badge: ChatIcon? {
        switch attachment.kind {
        case .gif: .gif
        case .video: .play
        case .image, .audio, .voice, .other: nil
        }
    }
}
