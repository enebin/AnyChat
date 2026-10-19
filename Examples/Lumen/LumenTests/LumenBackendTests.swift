import XCTest
import AnyChatUI
@testable import Lumen

@MainActor
final class LumenBackendTests: XCTestCase {
    private let question = "Help me make a cafe mocha at home"

    func testAnswerStreamsInPlaceAndFinishes() async throws {
        // Given
        let backend = LumenBackend(wordDelay: .zero)

        // When
        let channel = backend.newChat()
        backend.send(text: question, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.last?.answer?.phase == .done }

        // Then
        let messages = try backend.messages(channelID: channel.id)
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages[1].plainText.hasPrefix("A good café mocha"))
        XCTAssertFalse(backend.isGenerating(channelID: channel.id))
        XCTAssertEqual(backend.channel(id: channel.id)?.lastMessage?.id, messages[1].id)
    }

    func testStopKeepsTextSoFarAndEndsGeneration() async throws {
        // Given
        let backend = LumenBackend(wordDelay: .milliseconds(20))
        let channel = backend.newChat()
        backend.send(text: question, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.last?.answer?.phase == .streaming }

        // When
        backend.stop(channelID: channel.id)
        let stoppedText = try backend.messages(channelID: channel.id).last?.plainText
        await keepRunning(for: .milliseconds(200))

        // Then
        let answer = try XCTUnwrap(backend.messages(channelID: channel.id).last)
        XCTAssertEqual(answer.answer?.phase, .stopped)
        XCTAssertEqual(answer.plainText, stoppedText)
        XCTAssertFalse(backend.isGenerating(channelID: channel.id))
    }

    func testSendingDuringAnAnswerStopsItSoStopEndsEverything() async throws {
        // Given
        let backend = LumenBackend(wordDelay: .milliseconds(20))
        let channel = backend.newChat()
        backend.send(text: question, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.last?.answer?.phase == .streaming }
        let photo = ChatMessage(
            id: UUID().uuidString,
            sender: LumenBackend.me,
            createdAt: Date(),
            attachments: [ChatAttachment(id: "photo", kind: .image, url: URL(fileURLWithPath: "/tmp/photo.jpg"))]
        )

        // When
        backend.send(photo, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.count == 4 }
        backend.stop(channelID: channel.id)
        let stoppedTexts = try backend.messages(channelID: channel.id).map(\.plainText)
        await keepRunning(for: .milliseconds(200))

        // Then
        let messages = try backend.messages(channelID: channel.id)
        XCTAssertEqual(messages.compactMap(\.answer?.phase), [.stopped, .stopped])
        XCTAssertEqual(messages.map(\.plainText), stoppedTexts)
        XCTAssertFalse(backend.isGenerating(channelID: channel.id))
    }

    func testRegenerateRewritesTheSameMessage() async throws {
        // Given
        let backend = LumenBackend(wordDelay: .zero)
        let channel = backend.newChat()
        backend.send(text: question, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.last?.answer?.phase == .done }
        let first = try XCTUnwrap(backend.messages(channelID: channel.id).last)
        backend.setFeedback(.good, messageID: first.id, channelID: channel.id)

        // When
        backend.regenerate(messageID: first.id, channelID: channel.id)
        await waitUntil { (try? backend.messages(channelID: channel.id))?.last?.answer?.phase == .done }

        // Then
        let messages = try backend.messages(channelID: channel.id)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[1].id, first.id)
        XCTAssertNotEqual(messages[1].plainText, first.plainText)
        XCTAssertNil(messages[1].attributes[Feedback.self])
    }

    func testNewChatStaysOutOfTheListUntilItsFirstMessageNamesIt() throws {
        // Given
        let backend = LumenBackend(wordDelay: .zero)
        let channel = backend.newChat()
        XCTAssertNil(channel.name)
        XCTAssertFalse(backend.sortedChannels.contains { $0.id == channel.id })
        XCTAssertEqual(backend.newChat().id, channel.id)

        // When
        backend.send(text: question, channelID: channel.id)

        // Then
        let listed = try XCTUnwrap(backend.sortedChannels.first { $0.id == channel.id })
        XCTAssertEqual(listed.name, LumenReplies.title(for: question))
        XCTAssertNotEqual(backend.newChat().id, channel.id)
    }

    /// Lets the backend's tasks run for a while, to show that nothing more arrives.
    private func keepRunning(for duration: Duration) async {
        let deadline = ContinuousClock.now.advanced(by: duration)
        while ContinuousClock.now < deadline {
            await Task.yield()
        }
    }

    private func waitUntil(timeout: Duration = .seconds(5), _ predicate: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !predicate() {
            guard ContinuousClock.now < deadline else {
                XCTFail("timed out waiting for the expected state")
                return
            }
            await Task.yield()
        }
    }
}
