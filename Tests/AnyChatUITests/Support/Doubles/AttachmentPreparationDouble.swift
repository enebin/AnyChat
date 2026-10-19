import Foundation
import AnyChatCore
@testable import AnyChatUI

/// Stands in for `AttachmentPreparer` so the Store can be driven without touching files.
@MainActor
final class AttachmentPreparationDouble {
    private(set) var preparedSources: [[AttachmentSource]] = []
    private(set) var discarded: [[ChatOutgoingAttachment]] = []
    var result: Result<[ChatOutgoingAttachment], any Error> = .success([])
    /// When `true`, each call suspends until `resume(with:)` is called.
    var holds = false
    private var held: [CheckedContinuation<[ChatOutgoingAttachment], any Error>] = []

    func prepare(_ sources: [AttachmentSource]) async throws -> [ChatOutgoingAttachment] {
        preparedSources.append(sources)
        if holds {
            return try await withCheckedThrowingContinuation { held.append($0) }
        }
        return try result.get()
    }

    func discard(_ attachments: [ChatOutgoingAttachment]) {
        discarded.append(attachments)
    }

    /// Completes the oldest held call.
    func resume(with result: Result<[ChatOutgoingAttachment], any Error>) {
        guard !held.isEmpty else {
            return
        }
        held.removeFirst().resume(with: result)
    }
}
