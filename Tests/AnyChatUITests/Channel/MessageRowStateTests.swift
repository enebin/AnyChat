import Foundation
import AnyChatCore
import XCTest
@testable import AnyChatUI

final class MessageRowStateTests: XCTestCase {
    private enum Constant {
        static let me = "me"
        static let start = MessageFixtures.start
        static let minute: TimeInterval = 60
        static let day: TimeInterval = 24 * 3_600
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar
        }()
        static let locale = Locale(identifier: "en_US_POSIX")
        static let quotedText = "Lunch at noon?"
    }

    // MARK: - Grouping

    /// One sender's messages within a minute form a run: the name on the first, the picture and the
    /// time on the last.
    func testSameSenderWithinAMinuteFormsARun() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            MessageFixtures.message("b", from: "alice", at: Constant.start.addingTimeInterval(10)),
            MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(20))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.groupPosition), [.first, .middle, .last])
        XCTAssertEqual(rows.map(\.showsSenderName), [true, false, false])
        XCTAssertEqual(rows.map(\.showsSenderAvatar), [false, false, true])
        XCTAssertEqual(rows.map { $0.timeText != nil }, [false, false, true])
    }

    /// A host's picture shows where the default one does, and is hidden on the rows above it.
    func testAvatarSlotShowsOnTheLastRowOfARun() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            MessageFixtures.message("b", from: "alice", at: Constant.start.addingTimeInterval(10)),
            MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(20)),
            MessageFixtures.message("d", from: "bob", at: Constant.start.addingTimeInterval(30))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.showsAvatarSlot), [false, false, true, true])
    }

    /// A host's name view goes where the default name does: the top of each run.
    func testSenderNameSlotShowsOnTheFirstRowOfARun() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            MessageFixtures.message("b", from: "alice", at: Constant.start.addingTimeInterval(10)),
            MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(20)),
            MessageFixtures.message("d", from: "bob", at: Constant.start.addingTimeInterval(30))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.showsSenderNameSlot), [true, false, false, true])
    }

    /// The host decides what to draw for a message without a sender, so its picture and name still show.
    func testHostSlotsShowWithoutASender() {
        // Given
        let message = MessageFixtures.message("a", from: nil, at: Constant.start)

        // When
        let row = makeRows([message])[0]

        // Then
        XCTAssertFalse(row.showsSenderAvatar)
        XCTAssertTrue(row.showsAvatarSlot)
        XCTAssertFalse(row.showsSenderName)
        XCTAssertTrue(row.showsSenderNameSlot)
    }

    /// A new minute or a new sender starts a new run.
    func testNewMinuteOrSenderBreaksTheRun() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            MessageFixtures.message("b", from: "alice", at: Constant.start.addingTimeInterval(Constant.minute)),
            MessageFixtures.message("c", from: "bob", at: Constant.start.addingTimeInterval(Constant.minute + 1))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.groupPosition), [.single, .single, .single])
        XCTAssertEqual(rows.map { $0.message.sender?.id }, ["alice", "alice", "bob"])
    }

    /// A system message stands alone, with no sender and no time, and splits the runs around it.
    func testSystemMessageStandsAlone() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            MessageFixtures.message("b", from: nil, .system("Bob joined"), at: Constant.start.addingTimeInterval(1)),
            MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(2))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.groupPosition), [.single, .single, .single])
        XCTAssertEqual(rows[1].content, .system("Bob joined"))
        XCTAssertNil(rows[1].message.sender)
        XCTAssertNil(rows[1].timeText)
    }

    /// A message alone in its run carries both the name and the picture.
    func testSingleMessageShowsNameAndPicture() {
        // Given
        let messages = [MessageFixtures.message("a", from: "alice")]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows[0].groupPosition, .single)
        XCTAssertTrue(rows[0].showsSenderName)
        XCTAssertTrue(rows[0].showsSenderAvatar)
    }

    /// Only rows after the first of a run sit close under the row above; the slot context carries
    /// the same position.
    func testJoinsPreviousAndContextFollowThePosition() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: Constant.me, at: Constant.start),
            MessageFixtures.message("b", from: Constant.me, at: Constant.start.addingTimeInterval(10)),
            MessageFixtures.message("c", from: Constant.me, at: Constant.start.addingTimeInterval(20)),
            MessageFixtures.message("d", from: "alice", at: Constant.start.addingTimeInterval(30))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.joinsPrevious), [false, true, true, false])
        XCTAssertEqual(
            rows.map(\.context),
            [
                MessageRowContext(isMine: true, groupPosition: .first),
                MessageRowContext(isMine: true, groupPosition: .middle),
                MessageRowContext(isMine: true, groupPosition: .last),
                MessageRowContext(isMine: false, groupPosition: .single)
            ]
        )
    }

    /// Neither my own messages nor system lines show a sender.
    func testMineAndSystemShowNoSender() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: Constant.me, at: Constant.start),
            MessageFixtures.message("b", from: nil, .system("Bob joined"), at: Constant.start.addingTimeInterval(Constant.minute))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.showsSenderName), [false, false])
        XCTAssertEqual(rows.map(\.showsSenderAvatar), [false, false])
        XCTAssertEqual(rows.map(\.showsAvatarSlot), [false, false])
        XCTAssertEqual(rows.map(\.showsSenderNameSlot), [false, false])
    }

    func testSystemMessageRetainsSenderWithoutShowingSenderOrReceipt() {
        // Given
        let message = MessageFixtures.message("system", from: Constant.me, .system("Channel renamed"), receipt: .read)

        // When
        let row = makeRows([message])[0]

        // Then
        XCTAssertEqual(row.message, message)
        XCTAssertEqual(row.groupPosition, .single)
        XCTAssertFalse(row.showsSenderName)
        XCTAssertFalse(row.showsSenderAvatar)
        XCTAssertNil(row.timeText)
        XCTAssertNil(row.receipt)
    }

    // MARK: - Replies

    /// A reply never joins the run above it, so its quote never sits between two bubbles.
    func testReplyStartsANewRunAndLaterMessagesCanJoinIt() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: "alice", at: Constant.start),
            reply("b", from: "alice", to: reference(from: "bob"), at: Constant.start.addingTimeInterval(10)),
            MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(20))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.groupPosition), [.single, .first, .last])
        XCTAssertNil(rows[0].replyQuote)
        XCTAssertNotNil(rows[1].replyQuote)
    }

    /// The line names whom the reply answers, from the current user's point of view.
    func testReplyQuoteLineNamesTheOriginalSender() {
        // Given
        let messages = [
            reply("a", from: Constant.me, to: reference(from: "bob"), at: Constant.start),
            reply("b", from: Constant.me, to: reference(from: Constant.me), at: Constant.start.addingTimeInterval(Constant.minute)),
            reply("c", from: "bob", to: reference(from: Constant.me), at: Constant.start.addingTimeInterval(2 * Constant.minute)),
            reply("d", from: "bob", to: reference(from: "carol"), at: Constant.start.addingTimeInterval(3 * Constant.minute)),
            reply("e", from: "bob", to: .unavailable(messageID: "gone"), at: Constant.start.addingTimeInterval(4 * Constant.minute)),
            reply("f", from: Constant.me, to: .unavailable(messageID: "gone"), at: Constant.start.addingTimeInterval(5 * Constant.minute))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map { $0.replyQuote?.line }, [
            "You replied to Bob", "You replied to yourself", "Replied to you", "Replied to Carol", "Replied", "You replied"
        ])
        XCTAssertEqual(rows[4].replyQuote?.text, ReplyQuote.unavailableText)
        XCTAssertEqual(rows[4].replyQuote?.isUnavailable, true)
    }

    /// Text is quoted as is; an attachment-only original shows its first picture and names it.
    func testReplyQuoteShowsTextOrTheFirstPicture() {
        // Given
        var photo = reference(from: "bob", content: .text(""))
        photo.attachments = [AttachmentFixtures.image]
        let messages = [
            reply("a", from: "alice", to: reference(from: "bob", content: .text(Constant.quotedText)), at: Constant.start),
            reply("b", from: "alice", to: photo, at: Constant.start.addingTimeInterval(Constant.minute)),
            reply("c", from: "alice", to: reference(from: "bob", content: .file(.voice)), at: Constant.start.addingTimeInterval(2 * Constant.minute)),
            reply("d", from: "alice", to: reference(from: "bob", content: .unsupported), at: Constant.start.addingTimeInterval(3 * Constant.minute))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map { $0.replyQuote?.text }, [Constant.quotedText, "Photo", "Voice message", ReplyQuote.fallbackText])
        XCTAssertEqual(rows.map { $0.replyQuote?.thumbnail }, [nil, AttachmentFixtures.image, nil, nil])
    }

    /// The reply bar names whom the user answers and previews the message in the quote's words.
    func testReplyBarTextNamesTheSenderAndPreviewsTheMessage() {
        // Given
        let others = MessageFixtures.message("a", from: "bob", .text(Constant.quotedText))
        let mine = MessageFixtures.message("b", from: Constant.me, .file(.voice))
        let unnamed = ChatMessage(id: "c", sender: ChatSender(id: "dana"), createdAt: Constant.start, content: .unsupported)

        // When
        let texts = [others, mine, unnamed].map { ReplyBarText($0, currentUserID: Constant.me) }

        // Then
        XCTAssertEqual(texts.map(\.title), ["Replying to Bob", "Replying to yourself", "Replying to dana"])
        XCTAssertEqual(texts.map(\.preview), [Constant.quotedText, "Voice message", ReplyQuote.fallbackText])
    }

    /// A system message never draws a quote.
    func testSystemMessageWithAReplyLinkHasNoQuote() {
        // Given
        let messages = [reply("a", from: nil, to: reference(from: "bob"), content: .system("Bob joined"), at: Constant.start)]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertNil(rows[0].replyQuote)
    }

    // MARK: - Mine

    /// My own messages retain their sender and show the receipt only at the end of the run.
    func testMyMessagesShowReceiptAtTheEnd() {
        // Given
        let messages = [
            MessageFixtures.message("a", from: Constant.me, at: Constant.start, receipt: .read),
            MessageFixtures.message("b", from: Constant.me, at: Constant.start.addingTimeInterval(5), receipt: .delivered)
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.isMine), [true, true])
        XCTAssertEqual(rows.map(\.message), messages)
        XCTAssertEqual(rows.map(\.showsSenderName), [false, false])
        XCTAssertEqual(rows.map(\.showsSenderAvatar), [false, false])
        XCTAssertEqual(rows.map(\.receipt), [nil, .delivered])
    }

    /// Someone else's receipt is never shown.
    func testOthersMessagesShowNoReceipt() {
        // Given
        let messages = [MessageFixtures.message("a", from: "alice", receipt: .read)]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertFalse(rows[0].isMine)
        XCTAssertNil(rows[0].receipt)
    }

    /// With nobody signed in, a message without a sender is not mine.
    func testNoSenderAndNoCurrentUserIsNotMine() {
        // Given
        let message = MessageFixtures.message("a", from: nil, .system("Maintenance tonight"))

        // When
        let rows = MessageRowState.rows(
            for: [message],
            currentUserID: nil,
            now: Constant.start,
            calendar: Constant.calendar,
            locale: Constant.locale
        )

        // Then
        XCTAssertFalse(rows[0].isMine)
        XCTAssertFalse(MessageRowState.isMine(message, currentUserID: nil))
    }

    // MARK: - Dates

    /// The first message and the first of each new day carry a date separator.
    func testDateSeparatorStartsEachDay() {
        // Given
        let messages = [
            MessageFixtures.message("a", at: Constant.start),
            MessageFixtures.message("b", at: Constant.start.addingTimeInterval(Constant.minute)),
            MessageFixtures.message("c", at: Constant.start.addingTimeInterval(Constant.day))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.dateSeparator?.day), ["Today", nil, "Wed, Nov 15"])
        XCTAssertEqual(rows[0].dateSeparator?.time, "10:13 PM")
        XCTAssertEqual(rows.map(\.dateSeparator?.date), [messages[0].createdAt, nil, messages[2].createdAt])
    }

    /// The day before today reads "Yesterday", and older days in this year show their date.
    func testDateSeparatorNamesYesterday() {
        // Given
        let messages = [
            MessageFixtures.message("a", at: Constant.start.addingTimeInterval(-2 * Constant.day)),
            MessageFixtures.message("b", at: Constant.start.addingTimeInterval(-Constant.day))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.dateSeparator?.day), ["Sun, Nov 12", "Yesterday"])
    }

    /// A date in an earlier year spells out the year.
    func testDateSeparatorShowsYearForPastYears() {
        // Given
        let messages = [MessageFixtures.message("a", at: Constant.start)]

        // When
        let rows = MessageRowState.rows(
            for: messages,
            currentUserID: Constant.me,
            now: Constant.start.addingTimeInterval(365 * Constant.day),
            calendar: Constant.calendar,
            locale: Constant.locale
        )

        // Then
        XCTAssertEqual(rows[0].dateSeparator?.day, "Nov 14, 2023")
        XCTAssertEqual(rows[0].timeText, "10:13")
    }

    // MARK: - Content

    /// File content without attachment metadata has nothing to draw, so it becomes a placeholder.
    func testFilesWithoutAttachmentsBecomePlaceholders() {
        // Given
        let messages = [
            MessageFixtures.message("a", .file(.image)),
            MessageFixtures.message("b", .files, at: Constant.start.addingTimeInterval(Constant.minute)),
            MessageFixtures.message("c", .unsupported, at: Constant.start.addingTimeInterval(2 * Constant.minute))
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.content), [.placeholder, .placeholder, .placeholder])
        XCTAssertEqual(rows.map(\.message), messages)
    }

    func testSenderUpdatesChangeAnOutgoingRowEvenWhenSenderIsHidden() {
        // Given
        let original = MessageFixtures.message("outgoing", from: Constant.me)
        var updated = original
        updated.sender?.name = "Updated name"

        // When
        let originalRow = makeRows([original])[0]
        let updatedRow = makeRows([updated])[0]

        // Then
        XCTAssertEqual(originalRow.id, updatedRow.id)
        XCTAssertFalse(updatedRow.showsSenderName)
        XCTAssertNotEqual(originalRow, updatedRow)
        XCTAssertEqual(updatedRow.message, updated)
        XCTAssertEqual(Set([originalRow, updatedRow]).count, 2)
    }

    func testCustomValueUpdatesChangeTheRowWithTheSameFallbackAndID() {
        // Given
        var original = MessageFixtures.message("custom")
        original.customContent = .init(CustomMessageFixtures.thinking)
        var updated = original
        updated.customContent = .init(CustomMessageFixtures.updatedThinking)

        // When
        let originalRows = makeRows([original])
        let updatedRows = makeRows([updated])

        // Then
        XCTAssertEqual(originalRows[0].id, updatedRows[0].id)
        XCTAssertEqual(originalRows[0].content, updatedRows[0].content)
        XCTAssertEqual(originalRows[0].message.customContent?.value(as: CustomMessageFixtures.Thinking.self), CustomMessageFixtures.thinking)
        XCTAssertEqual(updatedRows[0].message.customContent?.value(as: CustomMessageFixtures.Thinking.self), CustomMessageFixtures.updatedThinking)
        XCTAssertNotEqual(originalRows, updatedRows)
    }

    func testMixedContentDrawsAttachmentsAboveTheBodyAndKeepsTheMessageForSlots() {
        // Given
        let body = "The photo and report"
        let attachments = [AttachmentFixtures.image, AttachmentFixtures.document]
        let message = ChatMessage(
            id: "mixed", sender: .init(id: "assistant"), createdAt: Constant.start,
            text: body, attachments: attachments
        )

        // When
        let row = makeRows([message])[0]

        // Then
        XCTAssertEqual(row.message, message)
        XCTAssertEqual(row.message.content, .text(body))
        XCTAssertEqual(row.message.attachments, attachments)
        XCTAssertEqual(
            row.content,
            .attachments(.init(attachments, text: body))
        )
        guard case let .attachments(grouped) = row.content else { return XCTFail("Expected attachments") }
        XCTAssertEqual(grouped.media, [AttachmentFixtures.image])
        XCTAssertEqual(grouped.files, [AttachmentFixtures.document])
        XCTAssertEqual(grouped.text, body)
        XCTAssertEqual(row.groupPosition, .single)
        XCTAssertTrue(row.showsSenderName)
        XCTAssertTrue(row.showsSenderAvatar)
    }

    func testAttachmentOnlyMessagesHaveNoBody() {
        // Given
        let message = ChatMessage(id: "attachment", createdAt: Constant.start, attachments: [AttachmentFixtures.image])

        // When
        let row = makeRows([message])[0]

        // Then
        guard case let .attachments(grouped) = row.content else { return XCTFail("Expected attachments") }
        XCTAssertEqual(grouped.media, [AttachmentFixtures.image])
        XCTAssertEqual(grouped.files, [])
        XCTAssertNil(grouped.text)
        XCTAssertEqual(row.message.attachments, [AttachmentFixtures.image])
        XCTAssertFalse(row.showsSenderName)
        XCTAssertFalse(row.showsSenderAvatar)
    }

    func testAttachmentUpdatesInvalidateARowWithTheSameBodyAndID() {
        // Given
        let original = ChatMessage(id: "attachment", createdAt: Constant.start, attachments: [AttachmentFixtures.image])
        var updated = original
        updated.attachments = [AttachmentFixtures.updatedImage]

        // When
        let originalRow = makeRows([original])[0]
        let updatedRow = makeRows([updated])[0]

        // Then
        XCTAssertEqual(originalRow.id, updatedRow.id)
        XCTAssertEqual(updatedRow.content, .attachments(.init([AttachmentFixtures.updatedImage], text: "")))
        XCTAssertNotEqual(originalRow, updatedRow)
        XCTAssertEqual(updatedRow.message, updated)
        XCTAssertEqual(Set([originalRow, updatedRow]).count, 2)
    }

    /// Images, GIFs, and videos are media; the rest are files. Each group keeps its original order.
    func testAttachmentsSplitIntoMediaAndFilesInOrder() {
        // Given
        let attachments = [
            AttachmentFixtures.document,
            AttachmentFixtures.video,
            AttachmentFixtures.audio,
            AttachmentFixtures.image,
            AttachmentFixtures.gif
        ]
        let message = ChatMessage(id: "mixed", createdAt: Constant.start, attachments: attachments)

        // When
        let row = makeRows([message])[0]

        // Then
        guard case let .attachments(grouped) = row.content else { return XCTFail("Expected attachments") }
        XCTAssertEqual(grouped.media, [AttachmentFixtures.video, AttachmentFixtures.image, AttachmentFixtures.gif])
        XCTAssertEqual(grouped.files, [AttachmentFixtures.document, AttachmentFixtures.audio])
        XCTAssertEqual(row.message.attachments, attachments)
    }

    /// File content that does carry attachment metadata is drawn from that metadata.
    func testFileContentWithAttachmentsDrawsTheAttachments() {
        // Given
        var message = MessageFixtures.message("file", .file(.other))
        message.attachments = [AttachmentFixtures.document]

        // When
        let row = makeRows([message])[0]

        // Then
        XCTAssertEqual(row.content, .attachments(.init([AttachmentFixtures.document], text: "")))
    }

    func testUnsupportedContentStaysAPlaceholderEvenWithAttachments() {
        // Given
        var message = MessageFixtures.message("unsupported", .unsupported)
        message.attachments = [AttachmentFixtures.image]

        // When
        let row = makeRows([message])[0]

        // Then
        XCTAssertEqual(row.content, .placeholder)
    }

    // MARK: - Unsent messages

    /// A pending message right after my sent one, in the same minute, starts its own run.
    func testUnsentMessagesGroupOnlyWithEachOther() {
        // Given
        let messages = [
            MessageFixtures.message("sent", from: Constant.me, at: Constant.start, receipt: .read),
            MessageFixtures.message("pending", from: Constant.me, at: Constant.start.addingTimeInterval(10), sendingStatus: .pending),
            MessageFixtures.message("failed", from: Constant.me, at: Constant.start.addingTimeInterval(20), sendingStatus: .failed)
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.groupPosition), [.single, .first, .last])
    }

    /// The status takes the place of the time and receipt on every unsent row.
    func testUnsentMessagesShowNoTimeOrReceipt() {
        // Given
        let messages = [
            MessageFixtures.message("pending", from: Constant.me, at: Constant.start, receipt: .sent, sendingStatus: .pending),
            MessageFixtures.message("failed", from: Constant.me, at: Constant.start.addingTimeInterval(Constant.minute), receipt: .sent, sendingStatus: .failed)
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertEqual(rows.map(\.timeText), [nil, nil])
        XCTAssertEqual(rows.map(\.receipt), [nil, nil])
    }

    /// An unsent message's local time can fall before the received message above it, so it never
    /// opens a day of its own.
    func testUnsentMessageNeverStartsADay() {
        // Given
        let messages = [
            MessageFixtures.message("received", from: "alice", at: Constant.start.addingTimeInterval(Constant.day)),
            MessageFixtures.message("pending", from: Constant.me, at: Constant.start, sendingStatus: .pending)
        ]

        // When
        let rows = makeRows(messages)

        // Then
        XCTAssertNotNil(rows[0].dateSeparator)
        XCTAssertNil(rows[1].dateSeparator)
    }

    /// Only this device's messages carry a status, so a failed send is drawn as mine even when the
    /// host passed no current user.
    func testUnsentMessageIsMineWithoutACurrentUser() {
        // Given
        let failed = MessageFixtures.message("failed", from: Constant.me, sendingStatus: .failed)

        // When
        let rows = MessageRowState.rows(for: [failed], currentUserID: nil, now: Constant.start, calendar: Constant.calendar, locale: Constant.locale)

        // Then
        XCTAssertTrue(rows[0].isMine)
    }

    /// A status change is a row change under the same id, so the row updates in place.
    func testSendingStatusChangeUpdatesTheRowInPlace() {
        // Given
        let pending = MessageFixtures.message("mine", from: Constant.me, sendingStatus: .pending)
        var sent = pending
        sent.sendingStatus = nil

        // When
        let before = makeRows([pending])
        let after = makeRows([sent])

        // Then
        XCTAssertEqual(before[0].id, after[0].id)
        XCTAssertNotEqual(before[0], after[0])
    }

    // MARK: - Reusing rows

    /// A row whose message and neighbors are unchanged is kept, even when a fresh build would differ.
    func testUnchangedRowsAreKeptAsTheyWere() {
        // Given
        let a = MessageFixtures.message("a", from: "alice", at: Constant.start)
        let b = MessageFixtures.message("b", from: "bob", at: Constant.start.addingTimeInterval(Constant.minute))
        let c = MessageFixtures.message("c", from: "carol", .text("Hel"), at: Constant.start.addingTimeInterval(2 * Constant.minute))
        let grown = MessageFixtures.message("c", from: "carol", .text("Hello"), at: c.createdAt)
        let previous = MessageRowState.rows(
            for: [a, b, c],
            currentUserID: Constant.me,
            now: Constant.start.addingTimeInterval(365 * Constant.day),
            calendar: Constant.calendar,
            locale: Constant.locale
        )

        // When
        let rows = makeRows([a, b, grown], reusing: previous)

        // Then
        XCTAssertEqual(rows[0], previous[0])
        XCTAssertEqual(rows[0].dateSeparator?.day, "Nov 14, 2023")
        XCTAssertEqual(rows[2].message, grown)
    }

    /// Reusing rows gives the same result as building them all, whether a message grows, joins a
    /// run, an older page shifts every row, or a message in the middle goes away.
    func testReusedRowsMatchAFreshBuild() {
        // Given
        let a = MessageFixtures.message("a", from: "alice", at: Constant.start)
        let b = MessageFixtures.message("b", from: "alice", .text("Hel"), at: Constant.start.addingTimeInterval(10))
        let grownB = MessageFixtures.message("b", from: "alice", .text("Hello"), at: b.createdAt)
        let c = MessageFixtures.message("c", from: "alice", at: Constant.start.addingTimeInterval(20))
        let older = MessageFixtures.message("older", from: "alice", at: Constant.start.addingTimeInterval(-Constant.day))
        let transitions: [(before: [ChatMessage], after: [ChatMessage])] = [
            ([a, b], [a, grownB]),
            ([a, b], [a, b, c]),
            ([a, b], [older, a, b]),
            ([a, b, c], [a, c])
        ]

        for (before, after) in transitions {
            // When
            let rows = makeRows(after, reusing: makeRows(before))

            // Then
            XCTAssertEqual(rows, makeRows(after), "\(before.map(\.id)) -> \(after.map(\.id))")
        }
    }

    // MARK: - Helpers

    private func reference(from senderID: String, content: ChatMessage.Content = .text("Hello")) -> ChatMessage.ReplyReference {
        ChatMessage.ReplyReference(messageID: "original-\(senderID)", sender: ChatSender(id: senderID, name: senderID.capitalized), content: content)
    }

    private func reply(
        _ id: String,
        from senderID: String?,
        to reference: ChatMessage.ReplyReference,
        content: ChatMessage.Content = .text("Sure"),
        at createdAt: Date
    ) -> ChatMessage {
        var message = MessageFixtures.message(id, from: senderID, content, at: createdAt)
        message.replyTo = reference
        return message
    }

    private func makeRows(_ messages: [ChatMessage], reusing previous: [MessageRowState] = []) -> [MessageRowState] {
        MessageRowState.rows(
            for: messages,
            currentUserID: Constant.me,
            now: Constant.start,
            reusing: previous,
            calendar: Constant.calendar,
            locale: Constant.locale
        )
    }
}
