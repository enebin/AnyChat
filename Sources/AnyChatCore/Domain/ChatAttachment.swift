import Foundation

/// A file attached to an ordinary message, without download or rendering state.
///
/// - Since: 1.0.0
public struct ChatAttachment: Sendable, Hashable, Identifiable {
    /// An image's dimensions in pixels, available before the image loads.
    ///
    /// - Since: 1.0.0
    public struct ImageSize: Sendable, Hashable {
        /// The pixel width.
        ///
        /// - Since: 1.0.0
        public var width: Int

        /// The pixel height.
        ///
        /// - Since: 1.0.0
        public var height: Int

        /// Creates pixel dimensions supplied by the backend adapter.
        ///
        /// - Since: 1.0.0
        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    /// The attachment's identity within its message.
    ///
    /// - Since: 1.0.0
    public var id: String

    /// The file classification supplied by the backend adapter.
    ///
    /// - Since: 1.0.0
    public var kind: ChatMessage.FileKind

    /// The URL from which the attachment can be read.
    ///
    /// - Since: 1.0.0
    public var url: URL

    /// The display file name, or `nil` when unavailable.
    ///
    /// - Since: 1.0.0
    public var fileName: String?

    /// The file size in bytes, or `nil` when unavailable.
    ///
    /// - Since: 1.0.0
    public var fileSize: Int64?

    /// Image dimensions in pixels, or `nil` when unavailable.
    ///
    /// - Since: 1.0.0
    public var imageSize: ImageSize?

    /// Creates an attachment from backend-neutral file metadata.
    ///
    /// - Since: 1.0.0
    public init(
        id: String,
        kind: ChatMessage.FileKind,
        url: URL,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        imageSize: ImageSize? = nil
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.imageSize = imageSize
    }
}
