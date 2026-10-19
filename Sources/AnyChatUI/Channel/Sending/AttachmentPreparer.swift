import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AnyChatCore

/// Copies picked items into the package's temporary folder and describes them for the adapter.
///
/// Each call gets its own folder, so equal file names from different picks never collide. Copies
/// handed to the adapter are the adapter's; `discard(_:)` deletes only copies that never reached it.
nonisolated struct AttachmentPreparer: Sendable {
    enum PreparationError: Error, Equatable {
        /// The photo library returned nothing for an item, for example one that is still in iCloud
        /// and could not be downloaded.
        case unreadablePhotoLibraryItem
        case unencodablePhoto
    }

    private static let cameraPhotoName = "photo"
    private static let cameraVideoName = "video"
    private static let jpegQuality: CGFloat = 0.9

    let directory: URL

    init(directory: URL = FileManager.default.temporaryDirectory.appending(path: "AnyChatOutgoing")) {
        self.directory = directory
    }

    /// Prepares every source or none: a message holding only part of a pick is not what the user
    /// chose.
    @concurrent
    func prepare(_ sources: [AttachmentSource]) async throws -> [ChatOutgoingAttachment] {
        let folder = directory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            var attachments: [ChatOutgoingAttachment] = []
            for (index, source) in sources.enumerated() {
                try Task.checkCancellation()
                // An index folder per item keeps two picks with the same name apart.
                let itemFolder = folder.appending(path: String(index))
                try FileManager.default.createDirectory(at: itemFolder, withIntermediateDirectories: true)
                attachments.append(try await prepare(source, in: itemFolder))
            }
            return attachments
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// Deletes the folders `prepare(_:)` made for these attachments. Folders outside `directory`
    /// are left alone, so a URL that did not come from `prepare(_:)` cannot delete anything else.
    func discard(_ attachments: [ChatOutgoingAttachment]) {
        let folders = Set(attachments.map { $0.fileURL.deletingLastPathComponent().deletingLastPathComponent() })
        for folder in folders where folder.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private func prepare(_ source: AttachmentSource, in folder: URL) async throws -> ChatOutgoingAttachment {
        switch source {
        case let .file(url):
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try store(url, named: url.lastPathComponent, into: folder)

        case let .cameraVideo(url):
            return try store(url, named: Self.cameraVideoName, into: folder, type: .quickTimeMovie)

        case let .cameraPhoto(image):
            guard let data = image.jpegData(compressionQuality: Self.jpegQuality) else {
                throw PreparationError.unencodablePhoto
            }
            let name = Self.named(Self.cameraPhotoName, type: .jpeg)
            let destination = folder.appending(path: name)
            try data.write(to: destination)
            return ChatOutgoingAttachment(fileURL: destination, kind: .image, fileName: name)

        case let .photoLibrary(item):
            let type = item.supportedContentTypes.first
            guard let picked = try await item.loadTransferable(type: PickedFile.self) else {
                throw PreparationError.unreadablePhotoLibraryItem
            }
            return try store(picked.url, named: picked.url.lastPathComponent, into: folder, type: type, moving: true)
        }
    }

    /// Copies `url`, or moves a file that is already a private copy, and gives it a name whose
    /// extension matches its type when the type is known, so the adapter can derive the MIME type.
    func store(
        _ url: URL,
        named name: String,
        into folder: URL,
        type knownType: UTType? = nil,
        moving: Bool = false
    ) throws -> ChatOutgoingAttachment {
        let type = knownType ?? (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        let fileName = type.map { Self.named(name, type: $0) } ?? name
        let destination = folder.appending(path: fileName)
        if moving {
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            try FileManager.default.moveItem(at: url, to: destination)
        } else {
            try FileManager.default.copyItem(at: url, to: destination)
        }
        return ChatOutgoingAttachment(fileURL: destination, kind: Self.kind(of: type), fileName: fileName)
    }

    static func named(_ name: String, type: UTType) -> String {
        guard let preferred = type.preferredFilenameExtension else {
            return name
        }
        let current = (name as NSString).pathExtension
        if let currentType = UTType(filenameExtension: current), currentType.conforms(to: type) || type.conforms(to: currentType) {
            return name
        }
        return "\(name).\(preferred)"
    }

    static func kind(of type: UTType?) -> ChatMessage.FileKind {
        guard let type else {
            return .other
        }
        if type.conforms(to: .gif) {
            return .gif
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        if type.conforms(to: .audio) {
            return .audio
        }
        return .other
    }
}

/// A photo library item delivered as a file, so a large video is never loaded into memory.
nonisolated private struct PickedFile: Transferable {
    let url: URL

    /// The photo library declines to import into `.item`, so the concrete types are listed;
    /// `.data` covers anything else it offers.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie, importing: keep)
        FileRepresentation(importedContentType: .image, importing: keep)
        FileRepresentation(importedContentType: .data, importing: keep)
    }

    /// The received file is deleted when the import returns, so it is moved somewhere that
    /// outlives the transfer.
    private static func keep(_ received: ReceivedTransferredFile) throws -> PickedFile {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: received.file.lastPathComponent)
        try FileManager.default.moveItem(at: received.file, to: destination)
        return PickedFile(url: destination)
    }
}
