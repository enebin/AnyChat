import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import UIKit

/// What a URL points at, and so how the loader turns it into a picture.
package enum RemoteImageKind: Hashable, Sendable {
    case image
    /// A video, shown as a frame generated from its start.
    case videoFrame
}

/// Loads and caches remote images in memory and on disk.
///
/// `AsyncImage` restarts from its empty phase every time a row is rebuilt, which makes a
/// scrolling list flicker. Keeping decoded images here lets a row show its picture on the first
/// frame. The disk keeps the downsampled result, so a relaunch neither downloads nor decodes the
/// full-size file again.
@MainActor
package final class RemoteImageLoader {
    package static let shared = RemoteImageLoader()

    private struct Key: Hashable {
        let url: URL
        let kind: RemoteImageKind
        let maxPixelLength: CGFloat
    }

    private struct Entry {
        let image: UIImage
        var lastUse: UInt64
    }

    private struct Loaded {
        let image: UIImage
        /// Bytes newly written to disk; zero for a disk hit or a failed write.
        let writtenBytes: Int
    }

    private let session: URLSession
    private let directory: URL
    private let capacity: Int
    private let byteLimit: Int
    private let diskByteLimit: Int

    private var cache: [Key: Entry] = [:]
    /// Stamped on an entry when it is used, so eviction can find the least recently used one.
    private var useClock: UInt64 = 0
    private var cachedBytes = 0
    private var inFlight: [Key: Task<Loaded?, Never>] = [:]
    /// Unknown until the first write scans the directory.
    private var diskBytes: Int?
    private var unrecordedDiskBytes = 0
    private var diskMaintenance: Task<Void, Never>?

    package init(
        session: URLSession = .shared,
        directory: URL = URL.cachesDirectory.appending(path: "AnyChatImages", directoryHint: .isDirectory),
        capacity: Int = 300,
        byteLimit: Int = 64 * 1_024 * 1_024,
        diskByteLimit: Int = 200 * 1_024 * 1_024
    ) {
        self.session = session
        self.directory = directory
        self.capacity = capacity
        self.byteLimit = byteLimit
        self.diskByteLimit = diskByteLimit
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    package func cachedImage(
        for url: URL,
        kind: RemoteImageKind = .image,
        maxPixelLength: CGFloat
    ) -> UIImage? {
        let key = Key(url: url, kind: kind, maxPixelLength: maxPixelLength)
        guard cache[key] != nil else { return nil }
        useClock += 1
        cache[key]?.lastUse = useClock
        return cache[key]?.image
    }

    package func image(
        for url: URL,
        kind: RemoteImageKind = .image,
        maxPixelLength: CGFloat
    ) async -> UIImage? {
        if let image = cachedImage(for: url, kind: kind, maxPixelLength: maxPixelLength) {
            return image
        }

        let key = Key(url: url, kind: kind, maxPixelLength: maxPixelLength)
        if let task = inFlight[key] {
            return await task.value?.image
        }

        let task = Task { [session, directory] in
            await Self.load(key, using: session, directory: directory)
        }
        inFlight[key] = task

        let loaded = await task.value
        inFlight[key] = nil

        guard let loaded else { return nil }
        store(loaded.image, for: key)
        if loaded.writtenBytes > 0 {
            recordDiskWrite(loaded.writtenBytes)
        }
        return loaded.image
    }

    // MARK: - Memory

    private func store(_ image: UIImage, for key: Key) {
        if let replaced = cache[key] {
            cachedBytes -= Self.byteCount(of: replaced.image)
        }
        useClock += 1
        cache[key] = Entry(image: image, lastUse: useClock)
        cachedBytes += Self.byteCount(of: image)

        while cache.count > capacity || (cachedBytes > byteLimit && cache.count > 1) {
            guard let leastRecent = cache.min(by: { $0.value.lastUse < $1.value.lastUse })?.key,
                  let evicted = cache.removeValue(forKey: leastRecent) else { break }
            cachedBytes -= Self.byteCount(of: evicted.image)
        }
    }

    private nonisolated static func byteCount(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    // MARK: - Disk

    func waitForDiskMaintenance() async {
        await diskMaintenance?.value
    }

    private func recordDiskWrite(_ bytes: Int) {
        unrecordedDiskBytes += bytes
        guard diskMaintenance == nil else { return }
        diskMaintenance = Task { await maintainDisk() }
    }

    /// Runs one scan or trim at a time. A file written while one runs may be counted by it and
    /// again as unrecorded bytes; that only brings the next trim early, never late.
    private func maintainDisk() async {
        while unrecordedDiskBytes > 0 {
            let added = unrecordedDiskBytes
            unrecordedDiskBytes = 0
            var total: Int
            if let diskBytes {
                total = diskBytes + added
            } else {
                total = await Self.directorySize(directory)
            }
            if total > diskByteLimit {
                total = await Self.trim(directory, to: diskByteLimit / 4 * 3)
            }
            diskBytes = total
        }
        diskMaintenance = nil
    }

    private nonisolated static func fileURL(for key: Key, in directory: URL) -> URL {
        let kindName = switch key.kind {
        case .image: "image"
        case .videoFrame: "video"
        }
        let name = "\(kindName)|\(Int(key.maxPixelLength))|\(key.url.absoluteString)"
        let digest = SHA256.hash(data: Data(name.utf8))
        return directory.appending(path: digest.map { String(format: "%02x", $0) }.joined())
    }

    private nonisolated static func load(_ key: Key, using session: URLSession, directory: URL) async -> Loaded? {
        let file = fileURL(for: key, in: directory)
        if let data = try? Data(contentsOf: file), let image = downsampled(data, to: key.maxPixelLength) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            return Loaded(image: image, writtenBytes: 0)
        }

        let loaded = switch key.kind {
        case .image: await download(key.url, to: key.maxPixelLength, using: session)
        case .videoFrame: await firstFrame(of: key.url, to: key.maxPixelLength)
        }
        guard let loaded else { return nil }
        return Loaded(image: loaded, writtenBytes: write(loaded, to: file, in: directory))
    }

    private nonisolated static func write(_ image: UIImage, to file: URL, in directory: URL) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let isOpaque = [.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo)
        guard let data = isOpaque ? image.jpegData(compressionQuality: 0.8) : image.pngData() else {
            return 0
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return data.count
        } catch {
            return 0
        }
    }

    // `async` without an `await` keeps these file system scans off the main actor.
    private nonisolated static func directorySize(_ directory: URL) async -> Int {
        files(in: directory).reduce(0) { $0 + $1.size }
    }

    /// Removes the least recently used files until at most `target` bytes remain, and returns
    /// what remains.
    private nonisolated static func trim(_ directory: URL, to target: Int) async -> Int {
        var remaining = files(in: directory).sorted { $0.modified < $1.modified }
        var total = remaining.reduce(0) { $0 + $1.size }
        while total > target, !remaining.isEmpty {
            let oldest = remaining.removeFirst()
            try? FileManager.default.removeItem(at: oldest.url)
            total -= oldest.size
        }
        return total
    }

    private nonisolated static func files(in directory: URL) -> [(url: URL, size: Int, modified: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
    }

    // MARK: - Network

    /// A `file:` URL has no HTTP response, so only HTTP responses are held to status 200.
    private nonisolated static func download(
        _ url: URL,
        to maxPixelLength: CGFloat,
        using session: URLSession
    ) async -> UIImage? {
        guard let (data, response) = try? await session.data(from: url) else {
            return nil
        }
        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
            return nil
        }
        return downsampled(data, to: maxPixelLength)
    }

    private nonisolated static func downsampled(_ data: Data, to maxPixelLength: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelLength
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated static func firstFrame(of url: URL, to maxPixelLength: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelLength, height: maxPixelLength)
        guard let (cgImage, _) = try? await generator.image(at: .zero) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
