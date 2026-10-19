import Foundation
import AnyChatCore

enum AttachmentFixtures {
    static let image = ChatAttachment(
        id: "image",
        kind: .image,
        url: URL(string: "https://example.com/photo.jpg")!,
        fileName: "photo.jpg",
        imageSize: .init(width: 640, height: 480)
    )
    static let document = ChatAttachment(
        id: "document",
        kind: .other,
        url: URL(string: "https://example.com/report.pdf")!,
        fileName: "report.pdf",
        fileSize: 1_024
    )
    static let gif = ChatAttachment(
        id: "gif",
        kind: .gif,
        url: URL(string: "https://example.com/wave.gif")!,
        fileName: "wave.gif"
    )
    static let video = ChatAttachment(
        id: "video",
        kind: .video,
        url: URL(string: "https://example.com/clip.mp4")!,
        fileName: "clip.mp4"
    )
    static let audio = ChatAttachment(
        id: "audio",
        kind: .audio,
        url: URL(string: "https://example.com/memo.m4a")!,
        fileName: "memo.m4a"
    )
    static let updatedImage: ChatAttachment = {
        var attachment = image
        attachment.url = URL(string: "https://example.com/updated-photo.jpg")!
        return attachment
    }()
}
