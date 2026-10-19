import SwiftUI

/// The circular avatar.
///
/// Without a single picture it arranges up to four circular member pictures on a circular backdrop.
package struct Avatar: View {
    /// What to draw inside the circle.
    nonisolated package enum Content: Hashable {
        case image(URL?)
        /// Composited in order. Anything past the fourth entry is ignored.
        case members([URL?])
        case placeholder
        case broadcast
    }

    /// The design source draws the glyph at four sevenths of the circle (32/56, 14.857/26).
    private static let glyphRatio: CGFloat = 4 / 7
    /// The largest avatar, 56pt, at 3x. Every avatar decodes at this one length so a picture shown
    /// at several sizes is cached once.
    private static let pixelLength: CGFloat = 168

    private let content: Content
    private let size: CGFloat
    private let background: Color
    private let tint: Color
    private let groupBackground: Color

    package init(
        _ content: Content,
        size: CGFloat,
        background: Color,
        tint: Color,
        groupBackground: Color = ChatPalette.groupAvatarBackground
    ) {
        self.content = content
        self.size = size
        self.background = background
        self.tint = tint
        self.groupBackground = groupBackground
    }

    package var body: some View {
        composition
            .frame(width: size, height: size)
            .clipShape(.circle)
    }

    @ViewBuilder
    private var composition: some View {
        switch content {
        case let .image(url):
            picture(url, width: size, height: size)

        case let .members(urls):
            members(urls)

        case .placeholder:
            glyph(.user, length: size * Self.glyphRatio)

        case .broadcast:
            glyph(.broadcast, length: size * Self.glyphRatio)
        }
    }

    @ViewBuilder
    private func members(_ urls: [URL?]) -> some View {
        switch urls.count {
        case 0:
            glyph(.user, length: size * Self.glyphRatio)

        case 1:
            picture(urls[0], width: size, height: size)

        default:
            ZStack(alignment: .topLeading) {
                groupBackground
                switch urls.count {
                case 2:
                    member(urls[1], x: 24.333, y: 24.333, diameter: 14.333)
                    member(urls[0], x: 5, y: 5, diameter: 24.333)
                case 3:
                    member(urls[0], x: 5, y: 5, diameter: 24.333)
                    member(urls[1], x: 24, y: 18, diameter: 17)
                    member(urls[2], x: 13, y: 29, diameter: 14)
                default:
                    member(urls[0], x: 5, y: 4, diameter: 23)
                    member(urls[1], x: 24, y: 13, diameter: 17)
                    member(urls[2], x: 21, y: 28, diameter: 15)
                    member(urls[3], x: 5, y: 27, diameter: 13)
                }
            }
        }
    }

    private func member(_ url: URL?, x: CGFloat, y: CGFloat, diameter: CGFloat) -> some View {
        let scale = size / 45
        return picture(url, width: diameter * scale, height: diameter * scale)
            .clipShape(.circle)
            .offset(x: x * scale, y: y * scale)
    }

    private func picture(_ url: URL?, width: CGFloat, height: CGFloat) -> some View {
        RemoteImage(url: url, maxPixelLength: Self.pixelLength) {
            glyph(.user, length: min(width, height) * Self.glyphRatio)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func glyph(_ icon: ChatIcon, length: CGFloat) -> some View {
        background.overlay {
            icon.sized(length)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Contents") {
    HStack(spacing: 12) {
        Avatar(.placeholder, size: 56, background: .gray, tint: .white)
        Avatar(.broadcast, size: 56, background: .green, tint: .white)
        Avatar(.members([nil]), size: 56, background: .gray, tint: .white)
        Avatar(.members([nil, nil]), size: 56, background: .gray, tint: .white)
        Avatar(.members([nil, nil, nil]), size: 56, background: .gray, tint: .white)
        Avatar(.members([nil, nil, nil, nil]), size: 56, background: .gray, tint: .white)
    }
    .padding()
}

#Preview("Sizes") {
    HStack(spacing: 12) {
        ForEach([20, 26, 34, 40, 56] as [CGFloat], id: \.self) { size in
            Avatar(.placeholder, size: size, background: .gray, tint: .white)
        }
    }
    .padding()
}
