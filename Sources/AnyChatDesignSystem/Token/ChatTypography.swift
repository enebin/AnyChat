import SwiftUI

/// System text styles that follow Dynamic Type.
nonisolated package enum ChatTypography {
    package static let headline: Font = .headline
    package static let listPreview: Font = .subheadline
    package static let quote: Font = .subheadline
    package static let replyBarTitle: Font = .footnote.weight(.semibold)
    package static let listTime: Font = .system(size: 14)
    package static let listChevron: Font = .system(size: 13, weight: .semibold)
    package static let header: Font = .callout.bold()
    package static let composer: Font = .callout
    package static let body: Font = .body
    package static let button: Font = .subheadline.weight(.semibold)
    package static let caption: Font = .caption
    package static let captionEmphasized: Font = .caption.weight(.semibold)
    package static let caption2: Font = .caption2
}
