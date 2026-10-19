import SwiftUI
import UIKit

/// System symbols used by the default chat views.
package enum ChatIcon: String, CaseIterable {
    case add = "plus"
    case broadcast = "megaphone.fill"
    case camera = "camera"
    case chat = "bubble.left.and.bubble.right"
    case close = "xmark"
    case create = "square.and.pencil"
    case done = "checkmark"
    case doneAll = "checkmark.circle.fill"
    case error = "exclamationmark.circle"
    case fileAudio = "waveform"
    case fileDocument = "doc"
    case freeze = "lock.fill"
    case gif = "livephoto"
    case jumpToLatest = "arrow.down"
    case leave = "rectangle.portrait.and.arrow.right"
    case message = "bubble.left"
    case notificationFilled = "bell.fill"
    case notificationOffFilled = "bell.slash.fill"
    case photo = "photo"
    case play = "play.fill"
    case search = "magnifyingglass"
    case send = "arrow.up.circle.fill"
    case spinner = "arrow.triangle.2.circlepath"
    case stop = "stop.circle.fill"
    case user = "person.fill"

    package var image: Image {
        Image(systemName: rawValue).renderingMode(.template)
    }

    package var uiImage: UIImage? {
        UIImage(systemName: rawValue)
    }

    package func sized(_ length: CGFloat) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: length, height: length)
    }

    /// Swipe labels draw at the image's intrinsic size, ignoring SwiftUI frames.
    package func redrawn(at length: CGFloat) -> Image {
        Image(uiImage: redrawnUIImage(at: length))
    }

    package func redrawnUIImage(at length: CGFloat) -> UIImage {
        let key = "\(rawValue)@\(length)"
        if let cached = Self.redrawnCache[key] { return cached }
        let size = CGSize(width: length, height: length)
        let result = UIGraphicsImageRenderer(size: size).image { _ in
            uiImage?.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
        Self.redrawnCache[key] = result
        return result
    }

    private static var redrawnCache: [String: UIImage] = [:]
}
