import Foundation

/// A file the user picked to send, waiting for the adapter to upload it.
///
/// The file lives in the package's temporary folder and belongs to the adapter once
/// `ChannelRepository.sendMessage(attachments:replyTo:)` is called: keep it as long as a resend
/// may need it, and move it elsewhere if that must survive a relaunch. The value carries no
/// `Data`, so a large video is never held in memory.
///
/// - Since: 1.0.0
public struct ChatOutgoingAttachment: Sendable, Hashable {
    /// A local `file:` URL.
    ///
    /// - Since: 1.0.0
    public var fileURL: URL

    /// The package's classification: GIF is `.gif`, other images `.image`, movies `.video`, audio
    /// `.audio`, and anything else `.other`. It never produces `.voice`.
    ///
    /// - Since: 1.0.0
    public var kind: ChatMessage.FileKind

    /// The file name. When the file's type is known it ends in a matching extension, so the MIME
    /// type can be derived from it; a file of unknown type keeps its name as picked.
    ///
    /// - Since: 1.0.0
    public var fileName: String

    /// - Since: 1.0.0
    public init(fileURL: URL, kind: ChatMessage.FileKind, fileName: String) {
        self.fileURL = fileURL
        self.kind = kind
        self.fileName = fileName
    }
}
