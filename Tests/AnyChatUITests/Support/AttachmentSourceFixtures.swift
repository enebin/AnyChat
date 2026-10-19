import Foundation
import AnyChatCore
@testable import AnyChatUI

/// Picked items and prepared files for attachment sending tests.
enum AttachmentSourceFixtures {
    static let photo = AttachmentSource.file(URL(fileURLWithPath: "/picked/photo.jpg"))
    static let report = AttachmentSource.file(URL(fileURLWithPath: "/picked/report.pdf"))
    static let preparedPhoto = ChatOutgoingAttachment(
        fileURL: URL(fileURLWithPath: "/outgoing/photo.jpg"),
        kind: .image,
        fileName: "photo.jpg"
    )
    static let preparedReport = ChatOutgoingAttachment(
        fileURL: URL(fileURLWithPath: "/outgoing/report.pdf"),
        kind: .other,
        fileName: "report.pdf"
    )
}
