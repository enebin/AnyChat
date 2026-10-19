import Foundation
import UIKit
import UniformTypeIdentifiers
import AnyChatCore
import XCTest
@testable import AnyChatUI

final class AttachmentPreparerTests: XCTestCase {
    private enum Constant {
        static let contents = Data("contents".utf8)
        static let imageSide: CGFloat = 4
    }

    private var root: URL!
    private var picked: URL!
    private var outgoing: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "AttachmentPreparerTests-\(UUID().uuidString)")
        picked = root.appending(path: "picked")
        outgoing = root.appending(path: "outgoing")
        try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A picked file is copied under its own name and classified by its type.
    func testFilesAreCopiedWithTheirNamesAndKinds() async throws {
        // Given
        let report = try write("report.pdf")
        let wave = try write("wave.gif")
        let clip = try write("clip.mov")

        // When
        let attachments = try await AttachmentPreparer(directory: outgoing).prepare([.file(report), .file(wave), .file(clip)])

        // Then
        XCTAssertEqual(attachments.map(\.fileName), ["report.pdf", "wave.gif", "clip.mov"])
        XCTAssertEqual(attachments.map(\.kind), [.other, .gif, .video])
        for attachment in attachments {
            XCTAssertTrue(attachment.fileURL.path.hasPrefix(outgoing.path))
            XCTAssertEqual(try Data(contentsOf: attachment.fileURL), Constant.contents)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.path))
    }

    /// Two picked files with the same name stay apart.
    func testSameNamesDoNotCollide() async throws {
        // Given
        let first = try write("same.txt", in: "a")
        let second = try write("same.txt", in: "b")

        // When
        let attachments = try await AttachmentPreparer(directory: outgoing).prepare([.file(first), .file(second)])

        // Then
        XCTAssertNotEqual(attachments[0].fileURL, attachments[1].fileURL)
    }

    /// A camera photo becomes a JPEG with a matching extension.
    func testCameraPhotoIsSavedAsJPEG() async throws {
        // Given
        let image = UIGraphicsImageRenderer(size: CGSize(width: Constant.imageSide, height: Constant.imageSide)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: Constant.imageSide, height: Constant.imageSide))
        }

        // When
        let attachments = try await AttachmentPreparer(directory: outgoing).prepare([.cameraPhoto(image)])

        // Then
        XCTAssertEqual(attachments.first?.kind, .image)
        XCTAssertEqual(attachments.first.map { UTType(filenameExtension: ($0.fileName as NSString).pathExtension) }, UTType.jpeg)
        XCTAssertNotNil(attachments.first.flatMap { UIImage(contentsOfFile: $0.fileURL.path) })
    }

    /// One unreadable item fails the whole pick and leaves no copies behind.
    func testOneMissingFileFailsTheWholePick() async throws {
        // Given
        let report = try write("report.pdf")
        let missing = picked.appending(path: "missing.pdf")

        // When
        do {
            _ = try await AttachmentPreparer(directory: outgoing).prepare([.file(report), .file(missing)])
            XCTFail("Expected the pick to fail")
        } catch {
            // Then
            XCTAssertEqual(try leftovers(), [])
        }
    }

    /// A cancelled run copies nothing and leaves no folder behind. Picked files copy without
    /// suspending, so a cancel that lands between two items cannot be staged here.
    func testCancelledPreparationLeavesNoCopies() async throws {
        // Given
        let sources = [AttachmentSource.file(try write("a.txt")), .file(try write("b.txt"))]
        let preparer = AttachmentPreparer(directory: outgoing)

        // When
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await preparer.prepare(sources)
        }
        let result = await task.result

        // Then
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(try leftovers(), [])
    }

    /// Discarding deletes the folder of the run that made the copies.
    func testDiscardDeletesTheCopies() async throws {
        // Given
        let preparer = AttachmentPreparer(directory: outgoing)
        let attachments = try await preparer.prepare([.file(try write("a.txt")), .file(try write("b.txt"))])

        // When
        preparer.discard(attachments)

        // Then
        XCTAssertEqual(try leftovers(), [])
    }

    /// Discarding leaves alone a folder that `prepare(_:)` did not make.
    func testDiscardIgnoresFoldersOutsideItsDirectory() throws {
        // Given
        let foreign = try write("keep.txt", in: "nested")
        let attachment = ChatOutgoingAttachment(fileURL: foreign, kind: .other, fileName: "keep.txt")

        // When
        AttachmentPreparer(directory: outgoing).discard([attachment])

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    /// A moved photo library file whose move fails still has its intermediate folder removed.
    func testFailedMoveRemovesTheIntermediateFolder() throws {
        // Given
        let received = try write("photo.jpg", in: "received")
        let folder = outgoing.appending(path: "item")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Constant.contents.write(to: folder.appending(path: "photo.jpg"))

        // When
        XCTAssertThrowsError(
            try AttachmentPreparer(directory: outgoing).store(received, named: "photo.jpg", into: folder, type: .jpeg, moving: true)
        )

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: received.deletingLastPathComponent().path))
    }

    func testNamesGainTheExtensionOfTheirType() {
        // Given / When / Then
        XCTAssertEqual(AttachmentPreparer.named("photo", type: .jpeg), "photo.jpeg")
        XCTAssertEqual(AttachmentPreparer.named("IMG_1.JPG", type: .jpeg), "IMG_1.JPG")
        XCTAssertEqual(AttachmentPreparer.named("clip.mov", type: .quickTimeMovie), "clip.mov")
        XCTAssertEqual(AttachmentPreparer.named("README", type: .data), "README")
    }

    func testKindsFollowTheType() {
        // Given / When / Then
        XCTAssertEqual(AttachmentPreparer.kind(of: .gif), .gif)
        XCTAssertEqual(AttachmentPreparer.kind(of: .png), .image)
        XCTAssertEqual(AttachmentPreparer.kind(of: .mpeg4Movie), .video)
        XCTAssertEqual(AttachmentPreparer.kind(of: .mp3), .audio)
        XCTAssertEqual(AttachmentPreparer.kind(of: .pdf), .other)
        XCTAssertEqual(AttachmentPreparer.kind(of: nil), .other)
    }

    private func leftovers() throws -> [String] {
        guard FileManager.default.fileExists(atPath: outgoing.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(atPath: outgoing.path)
    }

    private func write(_ name: String, in subfolder: String? = nil) throws -> URL {
        let folder = subfolder.map { picked.appending(path: $0) } ?? picked!
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Constant.contents.write(to: url)
        return url
    }
}
