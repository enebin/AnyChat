import UIKit
import XCTest
@testable import AnyChatDesignSystem

@MainActor
final class RemoteImageLoaderTests: XCTestCase {
    fileprivate enum Constant {
        static let smallWidth = 40
        static let smallHeight = 30
        static let pixelLength: CGFloat = 720
    }

    private var sourceDirectory: URL!
    private var cacheDirectory: URL!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        sourceDirectory = root.appendingPathComponent("source")
        cacheDirectory = root.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: sourceDirectory.deletingLastPathComponent())
    }

    // MARK: - Decoding

    /// A file URL has no HTTP status, and a large photo is decoded no larger than a thumbnail needs.
    func testFileURLLoadsDownsampledToTheMaximumPixelLength() async throws {
        // Given
        let url = try writeImage(width: 2_000, height: 1_000, named: "wide.png")
        let loader = makeLoader()

        // When
        let image = await loader.image(for: url)

        // Then
        let cgImage = try XCTUnwrap(image?.cgImage)
        XCTAssertEqual(CGFloat(cgImage.width), Constant.pixelLength)
        XCTAssertEqual(CGFloat(cgImage.height), Constant.pixelLength / 2)
        XCTAssertNotNil(loader.cachedImage(for: url))
    }

    /// One URL decoded at two lengths, as for an avatar and a thumbnail, keeps both pictures.
    func testEachPixelLengthIsCachedSeparately() async throws {
        // Given
        let url = try writeImage(width: 2_000, height: 1_000, named: "wide.png")
        let loader = makeLoader()
        let smallLength: CGFloat = 168

        // When
        let small = await loader.image(for: url, maxPixelLength: smallLength)
        let large = await loader.image(for: url)

        // Then
        XCTAssertEqual(small?.cgImage.map { CGFloat($0.width) }, smallLength)
        XCTAssertEqual(large?.cgImage.map { CGFloat($0.width) }, Constant.pixelLength)
        XCTAssertEqual(loader.cachedImage(for: url, maxPixelLength: smallLength)?.cgImage?.width, small?.cgImage?.width)
        XCTAssertEqual(cacheFiles().count, 2)
    }

    func testSmallImageKeepsItsSize() async throws {
        // Given
        let url = try writeImage(named: "small.png")
        let loader = makeLoader()

        // When
        let image = await loader.image(for: url)

        // Then
        let cgImage = try XCTUnwrap(image?.cgImage)
        XCTAssertEqual(cgImage.width, Constant.smallWidth)
        XCTAssertEqual(cgImage.height, Constant.smallHeight)
    }

    func testUnreadableDataFailsWithoutCaching() async throws {
        // Given
        let url = sourceDirectory.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: url)
        let loader = makeLoader()

        // When
        let image = await loader.image(for: url)

        // Then
        XCTAssertNil(image)
        XCTAssertNil(loader.cachedImage(for: url))
        XCTAssertEqual(cacheFiles().count, 0)
    }

    // MARK: - Disk

    /// A new loader, as after a relaunch, reads the stored thumbnail even when the source is gone.
    func testDiskCacheOutlivesTheLoaderAndTheSource() async throws {
        // Given
        let url = try writeImage(named: "kept.png")
        _ = await makeLoader().image(for: url)
        try FileManager.default.removeItem(at: url)

        // When
        let image = await makeLoader().image(for: url)

        // Then
        XCTAssertEqual(image?.cgImage?.width, Constant.smallWidth)
    }

    /// An image and a video frame of the same URL are different pictures.
    func testMemoryCacheSeparatesImagesFromVideoFrames() async throws {
        // Given
        let url = try writeImage(named: "still.png")
        let loader = makeLoader()

        // When
        _ = await loader.image(for: url)

        // Then
        XCTAssertNotNil(loader.cachedImage(for: url, kind: .image))
        XCTAssertNil(loader.cachedImage(for: url, kind: .videoFrame))
    }

    func testDiskCacheSeparatesImagesFromVideoFrames() async throws {
        // Given
        let url = try writeImage(named: "still.png")
        _ = await makeLoader().image(for: url)
        try FileManager.default.removeItem(at: url)

        // When
        let frame = await makeLoader().image(for: url, kind: .videoFrame)

        // Then
        XCTAssertNil(frame)
    }

    /// A picture with transparency is stored without losing it.
    func testDiskCacheKeepsTransparency() async throws {
        // Given
        let url = try writeImage(named: "clear.png", opaque: false)
        _ = await makeLoader().image(for: url)
        try FileManager.default.removeItem(at: url)

        // When
        let image = await makeLoader().image(for: url)

        // Then
        let alphaInfo = try XCTUnwrap(image?.cgImage?.alphaInfo)
        XCTAssertFalse([.none, .noneSkipFirst, .noneSkipLast].contains(alphaInfo))
    }

    /// Passing the disk limit removes the least recently used files first.
    func testDiskLimitRemovesTheLeastRecentlyUsedFile() async throws {
        // Given
        let first = try writeImage(named: "first.png")
        let second = try writeImage(named: "second.png")
        let third = try writeImage(named: "third.png")
        _ = await makeLoader().image(for: first)
        let fileSize = try XCTUnwrap(cacheFiles().first?.size)
        _ = await makeLoader().image(for: second)
        try FileManager.default.removeItem(at: first)
        try FileManager.default.removeItem(at: second)
        _ = await makeLoader().image(for: first)
        // Three files pass the limit; trimming to three quarters of it keeps two.
        let loader = makeLoader(diskByteLimit: fileSize * 14 / 5)

        // When
        _ = await loader.image(for: third)
        await loader.waitForDiskMaintenance()

        // Then
        let secondAfterTrim = await makeLoader().image(for: second)
        let firstAfterTrim = await makeLoader().image(for: first)
        XCTAssertNil(secondAfterTrim)
        XCTAssertNotNil(firstAfterTrim)
        XCTAssertEqual(cacheFiles().count, 2)
    }

    // MARK: - Memory

    func testMemoryCacheEvictsTheLeastRecentlyUsedImage() async throws {
        // Given
        let first = try writeImage(named: "first.png")
        let second = try writeImage(named: "second.png")
        let third = try writeImage(named: "third.png")
        let loader = makeLoader(capacity: 2)
        _ = await loader.image(for: first)
        _ = await loader.image(for: second)
        _ = loader.cachedImage(for: first)

        // When
        _ = await loader.image(for: third)

        // Then
        XCTAssertNotNil(loader.cachedImage(for: first))
        XCTAssertNil(loader.cachedImage(for: second))
        XCTAssertNotNil(loader.cachedImage(for: third))
    }

    // MARK: - Helpers

    private func makeLoader(capacity: Int = 300, diskByteLimit: Int = .max) -> RemoteImageLoader {
        RemoteImageLoader(directory: cacheDirectory, capacity: capacity, diskByteLimit: diskByteLimit)
    }

    private func cacheFiles() -> [(url: URL, size: Int)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return urls.map { ($0, (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private func writeImage(
        width: Int = Constant.smallWidth,
        height: Int = Constant.smallHeight,
        named name: String,
        opaque: Bool = true
    ) throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            (opaque ? UIColor.systemTeal : UIColor.systemTeal.withAlphaComponent(0.5)).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let url = sourceDirectory.appendingPathComponent(name)
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }
}

private extension RemoteImageLoader {
    func image(for url: URL, kind: RemoteImageKind = .image) async -> UIImage? {
        await image(for: url, kind: kind, maxPixelLength: RemoteImageLoaderTests.Constant.pixelLength)
    }

    func cachedImage(for url: URL, kind: RemoteImageKind = .image) -> UIImage? {
        cachedImage(for: url, kind: kind, maxPixelLength: RemoteImageLoaderTests.Constant.pixelLength)
    }
}
