import SwiftUI

/// Shows a remote image, showing a fallback view until it arrives.
///
/// A cached image is picked up in `init`, so a row that scrolls back into view does not flash
/// its fallback.
package struct RemoteImage<Fallback: View>: View {
    private let url: URL?
    private let kind: RemoteImageKind
    private let maxPixelLength: CGFloat
    private let fallback: Fallback

    @State private var image: UIImage?

    private struct Request: Hashable {
        let url: URL?
        let kind: RemoteImageKind
        let maxPixelLength: CGFloat
    }

    package init(
        url: URL?,
        kind: RemoteImageKind = .image,
        maxPixelLength: CGFloat,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.url = url
        self.kind = kind
        self.maxPixelLength = maxPixelLength
        self.fallback = fallback()
        _image = State(initialValue: url.flatMap {
            RemoteImageLoader.shared.cachedImage(for: $0, kind: kind, maxPixelLength: maxPixelLength)
        })
    }

    package var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .task(id: Request(url: url, kind: kind, maxPixelLength: maxPixelLength)) {
            guard let url else {
                image = nil
                return
            }
            if let cached = RemoteImageLoader.shared.cachedImage(for: url, kind: kind, maxPixelLength: maxPixelLength) {
                image = cached
                return
            }
            let loaded = await RemoteImageLoader.shared.image(for: url, kind: kind, maxPixelLength: maxPixelLength)
            // The shared load ignores this task's cancellation, so a superseded request still
            // finishes here and must not overwrite the newer request's image.
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
