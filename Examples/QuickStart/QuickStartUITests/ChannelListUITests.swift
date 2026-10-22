import XCTest

/// Drives the demo against its in-memory sample backend, so none of these need the network.
final class ChannelListUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 10
    private let firstChannelName = "Design team"
    private let firstChannelLatestMessage = "Ship it"
    private let firstChannelCreatedMessage = "Design team was created"
    /// The accessibility label of the first reaction badge below the first channel's latest message.
    private let firstChannelReaction = "Heart 2"
    private let assistantChannelName = "Assistant"
    private let assistantLastMessage = "Ask me anything"
    private let streamedReply = "Replies like this one arrive a few words at a time. The row grows in place, and the list stays on the newest message while it does."
    private let streamedReplyStart = "Replies"
    /// Longer than the sample reply's start delay plus its streaming time.
    private let streamTimeout: TimeInterval = 20
    /// Longer than the sample reply's start delay, after which a reply that was not stopped appears.
    private let replyStartWait: TimeInterval = 10
    /// The newest message of the sample history's second page.
    private let secondPageLastMessagePrefix = "Message 40 from"
    /// Longer than the sample backend's delay for older pages.
    private let olderPageSettleTime: TimeInterval = 4
    /// Re-anchoring after rows above are measured shifts the view by a fraction of a point; a real
    /// jump moves it by at least a row.
    private let maxAnchorDrift: CGFloat = 1
    private let attachmentChannelName = "Bob"
    private let replyChannelName = "Lunch"
    /// The bar while answering the first channel's latest message, which Alice sent.
    private let replyBarTitle = "Replying to Alice"
    private let sentReplyLine = "You replied to Alice"
    /// Well past the 60pt swipe threshold, so the row's resistance cannot keep it short.
    private let swipeTravel: CGFloat = 160
    /// The sample's reply to Alice, quoting her question.
    private let replyQuoteLine = "You replied to Alice"
    private let replyQuotedText = "Tacos again on Friday?"
    private let unavailableReplyText = "Original message unavailable"
    private let attachmentChannelCaption = "The view from the office"
    private let attachmentChannelPhoto = "landscape.jpg"
    private let attachmentChannelFile = "quarterly-report-final-version.pdf"
    private let attachmentChannelFileCaption = "Here is the report"
    private let jumpToLatestButton = "Jump to latest"
    /// The sample assistant's answer to a sent text, taller than the screen.
    private let answerText = (1...30).map { "Point \($0)" }.joined(separator: "\n")
    private let answerStart = "Point 1"
    /// The sent row's top lands 16pt below the bar, and its text sits inside the row's spacing and
    /// the bubble's padding. A list that followed the bottom leaves it far lower.
    private let questionTopSlack: CGFloat = 60
    /// Enough swipes to pass every page of the sample history.
    private let maxScrolls = 30
    private let sentText = "Sent from the UI test"
    private let emptyChannelName = "Book club"
    private let emptyChannelPlaceholder = "No messages"
    /// QuickStart's `channelEmptyState` view, and the text its button sends through the context.
    private let emptyState = "channelEmptyState"
    private let emptyStateButton = "Say hi 👋"
    private let emptyStateSentText = "Hi everyone 👋"
    /// Wraps the default composer field to its five-line limit.
    private let fiveLineDraft = "One\nTwo\nThree\nFour\nFive"
    /// The collapsed field centers its one line in its 43pt minimum height, so the line's top
    /// rises about 5pt once the field grows. A list that does not follow loses far more.
    private let collapsedFieldSlack: CGFloat = 6
    /// The sample backend fails a text containing "fail" the first time it is sent.
    private let failingText = "This one will fail"
    /// Longer than the system's long-press threshold for context menus.
    private let longPressDuration: TimeInterval = 1
    /// The first button of QuickStart's reaction bar above a long-pressed bubble.
    private let overlayReaction = "Heart"
    private let broadcastChannelName = "Announcements"
    private let frozenChannelName = "Archive"
    private let frozenChannelPreview = "Voice message"
    private let unavailablePlaceholder = "Chat is unavailable in this channel"
    private let frozenBannerText = "Channel is frozen"
    private let frozenChannelCreatedMessage = "Archive was created"
    /// QuickStart's own composer item, placed before the default + button.
    private let composerHostItem = "Gallery"
    private let headerPicture = "channelHeaderPicture"
    private let headerName = "channelHeaderName"
    private let headerSubtitle = "channelHeaderSubtitle"
    private let defaultHeaderName = "defaultChannelHeaderName"
    private let hostLeadingButton = "hostLeadingButton"
    /// Wider than the bar's spacing between two items, narrower than an empty glass item.
    private let maxLeadingItemGap: CGFloat = 24
    private let defaultDateSeparator = "messageDateSeparator"
    private let customDateSeparator = "customDateSeparator"
    private let firstChannelSubtitle = "4 members"
    private let listHeader = "channelListHeader"
    private let listHeaderButton = "See all"
    /// The sample backend's last channel, on its third page.
    private let lastChannelName = "Topic 25"
    /// Short enough that the header and the first row stay on screen.
    private let listDragDistance: CGFloat = 60
    /// The light incoming bubble measures about 0.93; the dark one about 0.2.
    private let lightSurfaceBrightness: CGFloat = 0.7
    /// The dark attach button measures about 0.1; its stale light gray, left on a dark screen, about 0.5.
    private let darkSurfaceBrightness: CGFloat = 0.3

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testChannelListShowsTheSampleChannels() {
        // Given / When
        let app = launchApp()

        // Then
        XCTAssertTrue(app.navigationBars["Messages"].waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Channel list")
    }

    @MainActor
    func testDefaultMessagesAppearance() {
        // Given
        let app = launchApp(customizations: false)
        XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(app.staticTexts[firstChannelName].frame.minX, 83, accuracy: 1)
        attachScreenshot(of: app, named: "Messages list default")

        // When
        app.staticTexts[firstChannelName].tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(app.buttons["Attach"].frame.width, 44, accuracy: 1)
        XCTAssertEqual(app.buttons["Attach"].frame.height, 44, accuracy: 1)
        attachScreenshot(of: app, named: "Messages conversation default")
        let field = composerField(in: app)
        field.tap()
        field.typeText(sentText)
        app.buttons["Send"].tap()

        // Then
        XCTAssertTrue(app.staticTexts[sentText].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(app.buttons["Freeze"].exists)
        XCTAssertFalse(app.buttons["Gallery"].exists)
        attachScreenshot(of: app, named: "Messages composer default")
    }

    /// The rows and the composer are hosted in UIKit and drawn with the screen's environment, which
    /// once stayed light after the system switched to dark.
    @MainActor
    func testSwitchingToDarkRedrawsAnOpenChannel() throws {
        // Given
        XCUIDevice.shared.appearance = .light
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = launchApp(customizations: false)
        let latest = openFirstChannelsLatestMessage(in: app)
        let attach = app.buttons["Attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: launchTimeout))
        // Inside the bubble's leading padding and the button's circle, clear of their text and glyph.
        let bubblePoint = CGPoint(x: latest.frame.minX - 6, y: latest.frame.midY)
        let attachPoint = CGPoint(x: attach.frame.minX + 8, y: attach.frame.midY)
        XCTAssertGreaterThan(try XCTUnwrap(brightness(in: app, at: bubblePoint)), lightSurfaceBrightness)

        // When
        XCUIDevice.shared.appearance = .dark

        // Then
        let redrawn = expectation(
            for: NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    let bubble = self.brightness(in: app, at: bubblePoint) ?? 1
                    let button = self.brightness(in: app, at: attachPoint) ?? 1
                    return bubble < self.darkSurfaceBrightness && button < self.darkSurfaceBrightness
                }
            },
            evaluatedWith: nil
        )
        wait(for: [redrawn], timeout: launchTimeout)
        attachScreenshot(of: app, named: "Messages conversation switched to dark")
    }

    @MainActor
    func testDefaultHeaderDoesNotCoverTheOldestDate() {
        for (name, createdText) in [(firstChannelName, firstChannelCreatedMessage),
                                    (frozenChannelName, frozenChannelCreatedMessage)] {
            // Given
            let app = launchApp(customizations: false)
            let channel = app.staticTexts[name]
            XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
            for _ in 0..<maxScrolls where !channel.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(channel.isHittable)
            channel.tap()
            let title = app.staticTexts["defaultChannelHeaderName"]
            XCTAssertTrue(title.waitForExistence(timeout: launchTimeout))
            let created = app.staticTexts[createdText]
            let list = app.collectionViews.firstMatch
            XCTAssertTrue(list.waitForExistence(timeout: launchTimeout))

            // When
            for _ in 0..<maxScrolls where !created.isHittable {
                list.swipeDown()
            }
            XCTAssertTrue(created.isHittable)
            list.swipeDown()

            // Then
            let date = app.staticTexts.matching(identifier: defaultDateSeparator).firstMatch
            XCTAssertTrue(date.isHittable)
            XCTAssertGreaterThanOrEqual(date.frame.minY, title.frame.maxY)
            if name == frozenChannelName {
                let banner = app.staticTexts[frozenBannerText]
                XCTAssertTrue(banner.isHittable)
                XCTAssertGreaterThanOrEqual(date.frame.minY, banner.frame.maxY)
            }
            attachScreenshot(of: app, named: "Oldest date below header - \(name)")
            app.terminate()
        }
    }

    @MainActor
    func testDefaultComposerGrowsAndDismissesKeyboardInteractively() {
        // Given
        let app = launchApp(customizations: false)
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let field = composerField(in: app)
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: launchTimeout))
        let singleLineHeight = field.frame.height
        let draft = "First line\nSecond line\nThird line\nFourth line"

        // When
        field.typeText(draft)

        // Then
        XCTAssertGreaterThan(field.frame.height, singleLineHeight)
        XCTAssertEqual(field.value as? String, draft)
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY)
        XCTAssertLessThanOrEqual(app.buttons["Send"].frame.maxY, keyboard.frame.minY)
        XCTAssertTrue(app.buttons["Send"].isHittable)
        attachScreenshot(of: app, named: "Multiline default composer")

        // When
        let window = app.windows.firstMatch.frame
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.midX, dy: field.frame.minY - app.buttons["Attach"].frame.height))
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.midX, dy: keyboard.frame.maxY - app.buttons["Attach"].frame.height))
        start.press(forDuration: 0.05, thenDragTo: end)

        // Then
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Keyboard dismissed interactively")

        // When
        app.buttons["Send"].tap()

        // Then
        let sent = app.staticTexts[draft]
        XCTAssertTrue(sent.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(sent.isHittable)
        XCTAssertLessThan(sent.frame.maxY, app.buttons["Attach"].frame.minY)
        attachScreenshot(of: app, named: "Newest message after keyboard dismissal")
    }

    /// Opening a channel lands on its newest message.
    @MainActor
    func testTappingAChannelOpensItsLatestMessages() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(latest.isHittable)
        attachScreenshot(of: app, named: "Channel")
    }

    /// The blank space in a row opens the channel too, not only the drawn text and avatar.
    @MainActor
    func testTappingBlankSpaceInARowOpensTheChannel() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[frozenChannelName]
        XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
        for _ in 0..<maxScrolls where !channel.isHittable {
            app.swipeUp()
        }
        let preview = app.staticTexts[frozenChannelPreview]
        XCTAssertTrue(preview.isHittable)
        let window = app.windows.firstMatch.frame
        let blank = CGPoint(x: (preview.frame.maxX + window.maxX) / 2, y: preview.frame.midY)

        // When
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: blank.x, dy: blank.y))
            .tap()

        // Then
        XCTAssertTrue(app.staticTexts[frozenBannerText].waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Opened from blank space")
    }

    /// An older page added above keeps the messages on screen where they were.
    @MainActor
    func testOlderPageKeepsVisibleMessagesInPlace() {
        // Given: opening the channel already shows rows near the top of the first page, so the
        // next, delayed page is on its way.
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        let yBefore = latest.frame.minY

        // When: the delayed page lands.
        let moved = expectation(
            for: NSPredicate { _, _ in abs(latest.frame.minY - yBefore) > self.maxAnchorDrift },
            evaluatedWith: nil
        )
        moved.isInverted = true
        wait(for: [moved], timeout: olderPageSettleTime)

        // Then: nothing moved, and the page did land above.
        XCTAssertEqual(latest.frame.minY, yBefore, accuracy: maxAnchorDrift)
        let secondPageLast = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", secondPageLastMessagePrefix)).firstMatch
        for _ in 0..<maxScrolls where !secondPageLast.exists {
            app.swipeDown()
        }
        XCTAssertTrue(secondPageLast.exists)
    }

    /// A reply that streams in grows in its own row and stays in view at the bottom.
    @MainActor
    func testStreamingReplyGrowsInPlace() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[assistantChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()
        let growing = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", streamedReplyStart)).firstMatch
        XCTAssertTrue(growing.waitForExistence(timeout: streamTimeout))
        let partialLabel = growing.label

        // Then
        let complete = app.staticTexts.matching(NSPredicate(format: "label == %@", streamedReply)).firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: streamTimeout))
        XCTAssertNotEqual(partialLabel, streamedReply)
        XCTAssertLessThanOrEqual(complete.frame.maxY, app.windows.firstMatch.frame.maxY)
        attachScreenshot(of: app, named: "Streamed reply")
    }

    /// While scrolled up, a reply growing at the bottom does not move the messages being read.
    @MainActor
    func testStreamingReplyDoesNotMoveMessagesWhileScrolledUp() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[assistantChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[assistantLastMessage].waitForExistence(timeout: launchTimeout))
        app.swipeDown()
        let reading = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Message '")).allElementsBoundByIndex
            .first { $0.isHittable }
        guard let reading else {
            return XCTFail("No message is on screen after scrolling up")
        }
        let yBefore = reading.frame.minY
        let replyRow = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", streamedReplyStart)).firstMatch
        XCTAssertFalse(replyRow.exists, "The reply must arrive after scrolling up, or this test checks nothing")

        // When
        let moved = expectation(
            for: NSPredicate { _, _ in abs(reading.frame.minY - yBefore) > self.maxAnchorDrift },
            evaluatedWith: nil
        )
        moved.isInverted = true
        wait(for: [moved], timeout: streamTimeout)

        // Then: nothing moved, and the reply did stream in below.
        XCTAssertEqual(reading.frame.minY, yBefore, accuracy: maxAnchorDrift)
        let complete = app.staticTexts.matching(NSPredicate(format: "label == %@", streamedReply)).firstMatch
        for _ in 0..<maxScrolls where !complete.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(complete.isHittable)
    }

    /// While the assistant answers, the send button is a stop button even with a draft. Tapping it
    /// ends the answer, and send comes back with the draft.
    @MainActor
    func testStopButtonEndsTheAssistantsAnswer() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[assistantChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let stop = app.buttons["Stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: launchTimeout))
        let field = composerField(in: app)
        field.tap()
        field.typeText(sentText)
        XCTAssertTrue(stop.exists)
        XCTAssertFalse(app.buttons["Send"].exists)
        attachScreenshot(of: app, named: "Stop button while answering")

        // When
        stop.tap()

        // Then
        XCTAssertTrue(app.buttons["Send"].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(stop.exists)
        let reply = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", streamedReplyStart)).firstMatch
        let arrived = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: reply)
        arrived.isInverted = true
        wait(for: [arrived], timeout: replyStartWait)
        attachScreenshot(of: app, named: "Composer after stopping")
    }

    /// Scrolling up shows the jump-to-latest button above the composer; tapping it returns to the
    /// newest message and the button goes away.
    @MainActor
    func testJumpToLatestButtonReturnsToTheNewestMessage() {
        // Given
        let app = launchApp()
        let latest = openFirstChannelsLatestMessage(in: app)
        let jump = app.buttons[jumpToLatestButton]
        XCTAssertFalse(jump.exists)
        for _ in 0..<maxScrolls where !jump.exists {
            app.swipeDown()
        }
        XCTAssertTrue(jump.exists)
        XCTAssertFalse(latest.isHittable)
        XCTAssertLessThanOrEqual(jump.frame.maxY, composerField(in: app).frame.minY)
        attachScreenshot(of: app, named: "Jump to latest")

        // When
        jump.tap()

        // Then
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: jump)
        let back = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: latest)
        wait(for: [gone, back], timeout: launchTimeout)
        attachScreenshot(of: app, named: "Back at the latest message")
    }

    /// With question to top, a sent message moves to just below the bar, stays there while the
    /// answer streams in below it, and the list does not follow the answer past the bottom.
    @MainActor
    func testQuestionToTopKeepsTheQuestionAtTheTopWhileTheAnswerStreams() {
        // Given
        let app = launchApp(questionToTop: true)
        let channel = app.staticTexts[assistantChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let stop = app.buttons["Stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: launchTimeout))
        stop.tap()
        let field = composerField(in: app)
        field.tap()
        field.typeText(sentText)
        let jump = app.buttons[jumpToLatestButton]

        // When
        app.buttons["Send"].tap()

        // Then: the question sits just below the bar, which is the bottom of the list for now.
        let sent = app.staticTexts[sentText]
        XCTAssertTrue(sent.waitForExistence(timeout: launchTimeout))
        let barBottom = app.navigationBars.firstMatch.frame.maxY
        let questionTop = sent.frame.minY
        XCTAssertGreaterThanOrEqual(questionTop, barBottom)
        XCTAssertLessThanOrEqual(questionTop - barBottom, questionTopSlack)
        XCTAssertFalse(jump.exists)
        attachScreenshot(of: app, named: "Question at the top")

        // Then: the answer grows below it without moving it.
        let answer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", answerStart)).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: streamTimeout))
        XCTAssertGreaterThan(answer.frame.minY, sent.frame.maxY)
        XCTAssertEqual(sent.frame.minY, questionTop, accuracy: maxAnchorDrift)

        // Then: past the bottom, the list stays on the question and the button shows.
        let complete = app.staticTexts.matching(NSPredicate(format: "label == %@", answerText)).firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: streamTimeout))
        XCTAssertEqual(sent.frame.minY, questionTop, accuracy: maxAnchorDrift)
        XCTAssertGreaterThan(complete.frame.maxY, field.frame.minY)
        XCTAssertTrue(jump.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Answer past the bottom")
    }

    /// Scrolling up loads older pages until the channel's first message.
    @MainActor
    func testScrollingUpLoadsEarlierMessages() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let firstMessage = app.staticTexts[firstChannelCreatedMessage]

        // When
        for _ in 0..<maxScrolls where !firstMessage.isHittable {
            app.swipeDown()
        }

        // Then
        XCTAssertTrue(firstMessage.isHittable)
        attachScreenshot(of: app, named: "Channel top")
    }

    /// QuickStart's `channelListHeader` sits above the first row and scrolls with the rows.
    @MainActor
    func testListHeaderSitsAboveTheRowsAndScrollsWithThem() {
        // Given
        let app = launchApp()
        let header = app.otherElements[listHeader]
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(header.exists)
        XCTAssertLessThanOrEqual(header.frame.maxY, channel.frame.minY)
        let headerTop = header.frame.minY
        let channelTop = channel.frame.minY

        // When
        let start = channel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Slow and held at the end, so the list does not fling the header off screen.
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -listDragDistance)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )

        // Then
        let channelMoved = channelTop - channel.frame.minY
        let headerMoved = headerTop - header.frame.minY
        XCTAssertGreaterThan(channelMoved, 0)
        XCTAssertEqual(headerMoved, channelMoved, accuracy: maxAnchorDrift)
        attachScreenshot(of: app, named: "List header scrolled")
    }

    /// The header's buttons take only their own taps, not taps on the space around them.
    @MainActor
    func testListHeaderButtonsTakeOnlyTheirOwnTaps() {
        // Given
        let app = launchApp()
        let header = app.otherElements[listHeader]
        XCTAssertTrue(header.waitForExistence(timeout: launchTimeout))

        // When
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Then
        XCTAssertFalse(app.alerts["QuickStart"].waitForExistence(timeout: 2))

        // When
        header.buttons[listHeaderButton].tap()

        // Then
        let alert = app.alerts["QuickStart"]
        XCTAssertTrue(alert.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(alert.staticTexts["\(listHeaderButton) tapped."].exists)
        alert.buttons["OK"].tap()
    }

    /// The header is outside the rows, so scrolling to the end still loads every page.
    @MainActor
    func testChannelListLoadsEveryPageBelowTheHeader() {
        // Given
        let app = launchApp()
        XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
        let last = app.staticTexts[lastChannelName]

        // When
        for _ in 0..<maxScrolls where !last.exists {
            app.swipeUp()
        }

        // Then
        XCTAssertTrue(last.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Channel list end")
    }

    @MainActor
    func testLeavingAChannelRemovesItsRow() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.swipeLeft()
        app.buttons["Leave"].tap()

        // Then
        XCTAssertTrue(app.alerts["QuickStart"].waitForExistence(timeout: launchTimeout))
        app.alerts["QuickStart"].buttons["OK"].tap()
        XCTAssertFalse(channel.exists)
        attachScreenshot(of: app, named: "After leaving")
    }

    /// Attachments load from the app bundle and their taps reach the host app.
    @MainActor
    func testAttachmentsRenderAndReportTaps() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[attachmentChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        XCTAssertTrue(app.staticTexts[attachmentChannelCaption].waitForExistence(timeout: launchTimeout))
        let photo = app.buttons[attachmentChannelPhoto].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.staticTexts[attachmentChannelFileCaption].exists)
        attachScreenshot(of: app, named: "Attachments")

        // When
        app.buttons[attachmentChannelFile].tap()

        // Then
        let alert = app.alerts["Attachment"]
        XCTAssertTrue(alert.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(alert.staticTexts[attachmentChannelFile].exists)
        alert.buttons["OK"].tap()

        // When
        app.swipeDown()

        // Then
        attachScreenshot(of: app, named: "Attachment grids")
    }

    /// A reply shows the design source's quote above its bubble: whom it answers and the original.
    @MainActor
    func testRepliesShowAQuoteOfTheOriginal() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[replyChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let unavailable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", unavailableReplyText))
            .firstMatch
        XCTAssertTrue(unavailable.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Reply quotes")

        // When
        let quote = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", replyQuoteLine, replyQuotedText))
            .firstMatch
        for _ in 0..<maxScrolls where !(quote.exists && quote.isHittable) {
            app.swipeDown()
        }

        // Then
        XCTAssertTrue(quote.isHittable)
        attachScreenshot(of: app, named: "Reply quote of a question")
    }

    /// Typed text is sent, appears at the bottom, and the composer stays above the keyboard.
    @MainActor
    func testSendingTextShowsTheMessage() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: launchTimeout))

        // When
        field.tap()
        field.typeText(sentText)

        // Then
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: launchTimeout))
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY)
        attachScreenshot(of: app, named: "Composer with text")

        // When
        app.buttons["Send"].tap()

        // Then
        let sent = app.staticTexts[sentText]
        XCTAssertTrue(sent.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(sent.isHittable)
        XCTAssertFalse(app.buttons["Send"].exists)
        attachScreenshot(of: app, named: "Sent message")
    }

    @MainActor
    func testEmptyChannelShowsNoMessagesByDefault() {
        // Given
        let app = launchApp(customizations: false)
        let channel = app.staticTexts[emptyChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let placeholder = app.staticTexts[emptyChannelPlaceholder]
        XCTAssertTrue(placeholder.waitForExistence(timeout: launchTimeout))
        XCTAssertLessThan(placeholder.frame.maxY, composerField(in: app).frame.minY)
        attachScreenshot(of: app, named: "Empty channel default")
    }

    /// The host's empty state stays above the composer, which still sends, and goes away with the
    /// first message.
    @MainActor
    func testEmptyStateSlotStaysAboveTheComposerUntilTheFirstMessage() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[emptyChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let emptyView = app.descendants(matching: .any)[emptyState]
        XCTAssertTrue(emptyView.waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(app.staticTexts[emptyChannelPlaceholder].exists)
        let field = composerField(in: app)
        XCTAssertLessThanOrEqual(emptyView.frame.maxY, field.frame.minY)
        attachScreenshot(of: app, named: "Empty state slot")

        // When
        field.tap()
        field.typeText(sentText)

        // Then
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(emptyView.isHittable)
        XCTAssertLessThanOrEqual(emptyView.frame.maxY, field.frame.minY)
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY)
        attachScreenshot(of: app, named: "Empty state slot above the keyboard")

        // When
        app.buttons["Send"].tap()

        // Then
        XCTAssertTrue(app.staticTexts[sentText].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(emptyView.exists)
        attachScreenshot(of: app, named: "First message replaces the empty state")
    }

    /// The same screen swapped from a channel with messages to an empty one shows the empty state.
    @MainActor
    func testSwitchingTheOpenChannelToAnEmptyOneShowsTheEmptyState() {
        // Given
        let app = launchApp(switchDemo: true)
        _ = openFirstChannelsLatestMessage(in: app)

        // When
        app.buttons["Open \(emptyChannelName)"].tap()

        // Then
        XCTAssertTrue(app.descendants(matching: .any)[emptyState].waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(app.staticTexts[firstChannelLatestMessage].exists)
        attachScreenshot(of: app, named: "Switched to the empty channel")
    }

    /// A drag that starts on blank space in the empty state still reaches the list and dismisses
    /// the keyboard, and the slot's button sends through the screen's composer context.
    @MainActor
    func testEmptyChannelDragDismissesTheKeyboardAndTheSlotSends() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[emptyChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let emptyView = app.descendants(matching: .any)[emptyState]
        XCTAssertTrue(emptyView.waitForExistence(timeout: launchTimeout))
        composerField(in: app).tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: launchTimeout))

        // When
        let window = app.windows.firstMatch.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: window.midX, dy: window.height * 0.3))
        let end = origin.withOffset(CGVector(dx: window.midX, dy: keyboard.frame.maxY - 40))
        start.press(forDuration: 0.05, thenDragTo: end)

        // Then
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Empty channel keyboard dismissed interactively")

        // When
        app.buttons[emptyStateButton].tap()

        // Then
        XCTAssertTrue(app.staticTexts[emptyStateSentText].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(emptyView.exists)
        attachScreenshot(of: app, named: "Empty state slot sent through the context")
    }

    /// A list showing its newest message keeps it above the composer while a draft makes the
    /// composer taller.
    @MainActor
    func testGrowingComposerKeepsTheNewestMessageInView() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let reaction = app.staticTexts[firstChannelReaction]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: launchTimeout))
        field.tap()
        let collapsedHeight = field.frame.height
        let gapAboveField = field.frame.minY - reaction.frame.maxY

        // When
        field.typeText(fiveLineDraft)

        // Then
        XCTAssertGreaterThan(field.frame.height, collapsedHeight)
        XCTAssertEqual(field.frame.minY - reaction.frame.maxY, gapAboveField, accuracy: collapsedFieldSlack)
        attachScreenshot(of: app, named: "Grown composer")
    }

    /// A list scrolled up into older messages stays where it is while the composer grows.
    @MainActor
    func testGrowingComposerDoesNotMoveMessagesWhileScrolledUp() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        app.swipeDown()
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: launchTimeout))
        field.tap()
        let reading = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Message '")).allElementsBoundByIndex
            .first { $0.isHittable }
        guard let reading else {
            return XCTFail("No message is on screen after scrolling up")
        }
        let yBefore = reading.frame.minY

        // When
        field.typeText(fiveLineDraft)

        // Then
        XCTAssertEqual(reading.frame.minY, yBefore, accuracy: maxAnchorDrift)
    }

    /// A send that fails shows the error icon, and Retry from its dialog sends it.
    @MainActor
    func testFailedMessageCanBeResent() {
        // Given
        let app = launchApp()
        let failed = sendFailingMessage(failingText, in: app)
        attachScreenshot(of: app, named: "Failed message")

        // When
        failed.tap()
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Failed message actions")
        retry.tap()

        // Then
        XCTAssertTrue(app.descendants(matching: .any)["Failed to send"].waitForNonExistence(timeout: launchTimeout))
        XCTAssertTrue(app.staticTexts[failingText].waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Resent message")
    }

    /// Remove takes a failed message out of the list.
    @MainActor
    func testFailedMessageCanBeRemoved() {
        // Given
        let app = launchApp()
        let failed = sendFailingMessage(failingText, in: app)

        // When
        failed.tap()
        let remove = app.buttons["Remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: launchTimeout))
        remove.tap()

        // Then
        XCTAssertTrue(failed.waitForNonExistence(timeout: launchTimeout))
    }

    /// Long-pressing a sent text message opens the default menu with Copy.
    @MainActor
    func testLongPressingAMessageOffersCopy() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))

        // When
        latest.press(forDuration: longPressDuration)

        // Then
        let copy = app.buttons["Copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(app.buttons["Retry"].exists)
        attachScreenshot(of: app, named: "Message menu")

        // When
        copy.tap()

        // Then
        XCTAssertTrue(copy.waitForNonExistence(timeout: launchTimeout))
    }

    /// Reply from the menu shows the reply bar above the composer and focuses the field; sending
    /// posts a reply that quotes the original and closes the bar.
    @MainActor
    func testReplyingFromTheMenuSendsAReply() {
        // Given
        let app = launchApp(customizations: false)
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        latest.press(forDuration: longPressDuration)
        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: launchTimeout))

        // When
        reply.tap()

        // Then
        let bar = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", replyBarTitle)).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.buttons["Cancel reply"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Reply bar")

        // When
        composerField(in: app).typeText(sentText)
        app.buttons["Send"].tap()

        // Then
        let quote = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", sentReplyLine, firstChannelLatestMessage))
            .firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(bar.waitForNonExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Sent reply")
    }

    /// Swiping a message toward the trailing edge starts a reply; a vertical drag still scrolls.
    @MainActor
    func testSwipingAMessageStartsAReplyAndDraggingStillScrolls() {
        // Given
        let app = launchApp(customizations: false)
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        let bar = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", replyBarTitle)).firstMatch
        let yBefore = latest.frame.minY

        // When
        app.swipeDown()

        // Then: the list scrolled, moving the message down or off the screen, and no reply began.
        XCTAssertTrue(!latest.isHittable || latest.frame.minY > yBefore)
        XCTAssertFalse(bar.exists)

        // When
        for _ in 0..<maxScrolls where !latest.isHittable {
            app.swipeUp()
        }
        // `swipeRight()` travels only the bubble's width, which is less than the threshold.
        let start = latest.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: swipeTravel, dy: 0)))

        // Then
        XCTAssertTrue(bar.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Reply from a swipe")
    }

    /// Closing the bar cancels the reply and keeps what was typed.
    @MainActor
    func testCancellingAReplyKeepsTheDraft() {
        // Given
        let app = launchApp(customizations: false)
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        latest.press(forDuration: longPressDuration)
        app.buttons["Reply"].tap()
        let field = composerField(in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: launchTimeout))
        field.typeText(sentText)

        // When
        app.buttons["Cancel reply"].tap()

        // Then
        XCTAssertTrue(app.buttons["Cancel reply"].waitForNonExistence(timeout: launchTimeout))
        XCTAssertEqual(composerField(in: app).value as? String, sentText)
    }

    /// Double-tapping a message reports it to the host, which QuickStart shows in an alert.
    @MainActor
    func testDoubleTappingAMessageReportsIt() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))

        // When
        latest.doubleTap()

        // Then
        let alert = app.alerts["Double-tapped"]
        XCTAssertTrue(alert.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(alert.staticTexts[firstChannelLatestMessage].exists)
        attachScreenshot(of: app, named: "Double-tapped message")
        alert.buttons["OK"].tap()
    }

    /// QuickStart's `channelHeader` draws a picture, a name, and a subtitle. The screen sizes it like
    /// the default header, so the navigation bar does not clip the text.
    @MainActor
    func testChannelHeaderSlotShowsPictureNameAndSubtitle() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let picture = app.staticTexts[headerPicture]
        let name = app.staticTexts[headerName]
        let subtitle = app.staticTexts[headerSubtitle]
        XCTAssertTrue(subtitle.waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(name.label, firstChannelName)
        XCTAssertEqual(subtitle.label, firstChannelSubtitle)
        // A clipped toolbar item squeezed both texts to zero width. The bar does not grow, so
        // both lines must also stay within its height.
        let window = app.windows.firstMatch.frame
        let bar = app.navigationBars.firstMatch.frame
        XCTAssertTrue(picture.isHittable)
        for text in [name, subtitle] {
            XCTAssertGreaterThan(text.frame.width, 0)
            XCTAssertGreaterThanOrEqual(text.frame.minX, picture.frame.maxX)
            XCTAssertLessThanOrEqual(text.frame.maxX, window.maxX)
            XCTAssertGreaterThanOrEqual(text.frame.minY, bar.minY)
            XCTAssertLessThanOrEqual(text.frame.maxY, bar.maxY)
        }
        attachScreenshot(of: app, named: "Channel header slot")
    }

    /// An empty `channelHeader` adds no toolbar item, so QuickStart's own leading button sits right
    /// after the back button with no empty item between them.
    @MainActor
    func testEmptyChannelHeaderLeavesTheLeadingSpotToTheHost() {
        // Given
        let app = launchApp(customizations: false, hiddenHeader: true)
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()
        for frame in 1...3 {
            attachScreenshot(of: app, named: "Hidden header push \(frame)")
        }

        // Then
        let button = app.buttons[hostLeadingButton]
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(button.isHittable)
        XCTAssertFalse(app.staticTexts[headerPicture].exists)
        XCTAssertFalse(app.staticTexts[defaultHeaderName].exists)
        let back = app.navigationBars.buttons["BackButton"]
        XCTAssertLessThan(button.frame.minX - back.frame.maxX, maxLeadingItemGap)
        attachScreenshot(of: app, named: "Hidden header")

        // When
        button.tap()

        // Then
        let alert = app.alerts["Leading button tapped"]
        XCTAssertTrue(alert.waitForExistence(timeout: launchTimeout))
        alert.buttons["OK"].tap()
    }

    /// QuickStart draws the sample reactions with `messageAccessory`, below the bubble on the
    /// sender's side.
    @MainActor
    func testMessageAccessoryShowsBelowTheBubble() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        let reaction = app.staticTexts[firstChannelReaction]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))
        XCTAssertGreaterThan(reaction.frame.minY, latest.frame.maxY)
        XCTAssertLessThanOrEqual(reaction.frame.minX, latest.frame.minX)
        attachScreenshot(of: app, named: "Message accessory")
    }

    /// QuickStart replaces the date separator with `messageDateSeparator`, so the oldest message's
    /// day shows the host's view and the default separator is gone.
    @MainActor
    func testDateSeparatorSlotReplacesTheDefaultSeparator() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let created = app.staticTexts[firstChannelCreatedMessage]
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: launchTimeout))

        // When
        for _ in 0..<maxScrolls where !created.isHittable {
            list.swipeDown()
        }
        XCTAssertTrue(created.isHittable)
        list.swipeDown()

        // Then
        let separator = app.staticTexts.matching(identifier: customDateSeparator).firstMatch
        XCTAssertTrue(separator.isHittable)
        XCTAssertLessThan(separator.frame.maxY, created.frame.minY)
        XCTAssertEqual(separator.label, separator.label.uppercased())
        XCTAssertFalse(app.staticTexts.matching(identifier: defaultDateSeparator).firstMatch.exists)
        attachScreenshot(of: app, named: "Date separator slot")
    }

    /// The message menu lifts the bubble alone, so a long press on the accessory below it opens
    /// nothing.
    @MainActor
    func testLongPressingAMessageAccessoryOpensNoMenu() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let reaction = app.staticTexts[firstChannelReaction]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))

        // When
        reaction.press(forDuration: longPressDuration)

        // Then
        XCTAssertFalse(app.buttons["Copy"].waitForExistence(timeout: 2))
    }

    /// A double tap on a failed message reports it without opening the Retry / Remove dialog, which
    /// a single tap opens once the double tap has failed.
    @MainActor
    func testDoubleTappingAFailedMessageDoesNotOpenItsDialog() {
        // Given
        let app = launchApp()
        let failed = sendFailingMessage(failingText, in: app)

        // When
        failed.doubleTap()

        // Then
        let alert = app.alerts["Double-tapped"]
        XCTAssertTrue(alert.waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(app.buttons["Retry"].exists)
        alert.buttons["OK"].tap()

        // When
        failed.tap()

        // Then
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: launchTimeout))
    }

    /// Long-pressing a failed message offers the same Retry and Remove as tapping it, without Copy.
    @MainActor
    func testLongPressingAFailedMessageOffersRetryAndRemove() {
        // Given
        let app = launchApp()
        let failed = sendFailingMessage(failingText, in: app)

        // When
        failed.press(forDuration: longPressDuration)

        // Then
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.buttons["Remove"].exists)
        XCTAssertFalse(app.buttons["Copy"].exists)
        // A failed message may not exist on the backend, so it cannot be answered.
        XCTAssertFalse(app.buttons["Reply"].exists)
        attachScreenshot(of: app, named: "Failed message menu")
    }

    // MARK: - Long-press overlay

    /// A long press opens QuickStart's overlay, a reaction bar above the bubble and the default
    /// items below it; a default item acts and closes it.
    @MainActor
    func testLongPressOverlayOpensAndADefaultItemClosesIt() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        let latest = openFirstChannelsLatestMessage(in: app)

        // When
        latest.press(forDuration: longPressDuration)

        // Then
        let reaction = app.buttons[overlayReaction]
        let copy = app.buttons["Copy"]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(copy.exists)
        XCTAssertTrue(app.buttons["Reply"].exists)
        attachScreenshot(of: app, named: "Long-press overlay")

        // When
        copy.tap()

        // Then
        XCTAssertTrue(reaction.waitForNonExistence(timeout: launchTimeout))
        XCTAssertFalse(copy.exists)
    }

    /// Tapping the dimmed area closes the overlay without acting.
    @MainActor
    func testTappingTheDimClosesTheOverlay() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        let latest = openFirstChannelsLatestMessage(in: app)
        latest.press(forDuration: longPressDuration)
        let reaction = app.buttons[overlayReaction]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))

        // When: the newest message sits low, so the upper screen is dim only.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()

        // Then
        XCTAssertTrue(reaction.waitForNonExistence(timeout: launchTimeout))
        XCTAssertTrue(latest.isHittable)
    }

    /// A long press over an attachment button opens the overlay and takes the touch from the
    /// button, so releasing does not open the attachment.
    @MainActor
    func testLongPressOverAnAttachmentOpensTheOverlayWithoutOpeningIt() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        let channel = app.staticTexts[attachmentChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let file = app.buttons[attachmentChannelFile]
        XCTAssertTrue(file.waitForExistence(timeout: launchTimeout))

        // When
        file.press(forDuration: longPressDuration)

        // Then
        XCTAssertTrue(app.buttons[overlayReaction].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(app.alerts["Attachment"].exists)
        attachScreenshot(of: app, named: "Long-press overlay over an attachment")

        // When
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()

        // Then
        XCTAssertTrue(app.buttons[overlayReaction].waitForNonExistence(timeout: launchTimeout))
        XCTAssertFalse(app.alerts["Attachment"].waitForExistence(timeout: 1))
    }

    /// A cell reused for another message keeps its geometry, so the bubble that scrolls into it
    /// must still open the overlay.
    @MainActor
    func testLongPressOverlayOpensOnABubbleThatScrolledIntoAReusedCell() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        _ = openFirstChannelsLatestMessage(in: app)
        app.swipeDown(velocity: .slow)
        // Away from the header and the composer, which sit over the list's edges.
        let middle = app.frame.insetBy(dx: 0, dy: app.frame.height / 3)
        let older = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Message ")).allElementsBoundByIndex
            .first { middle.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
        guard let older else { return XCTFail("No older message scrolled into view") }
        // A touch on a list that is still decelerating only stops it, so wait until it settles.
        var lastFrame = CGRect.null
        let settled = expectation(
            for: NSPredicate { _, _ in
                defer { lastFrame = older.frame }
                return older.frame == lastFrame
            },
            evaluatedWith: nil
        )
        wait(for: [settled], timeout: launchTimeout)

        // When
        older.press(forDuration: longPressDuration)

        // Then
        XCTAssertTrue(app.buttons[overlayReaction].waitForExistence(timeout: launchTimeout))
    }

    /// A failed message opens the overlay with Retry and Remove from the default items; the demo's
    /// reaction bar is hidden because the message is not on the backend.
    @MainActor
    func testLongPressOverlayOnAFailedMessageOffersRetryAndRemove() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        let failed = sendFailingMessage(failingText, in: app)

        // When
        failed.press(forDuration: longPressDuration)

        // Then
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.buttons["Remove"].exists)
        XCTAssertFalse(app.buttons[overlayReaction].exists)
    }

    /// Once the overlay opens, the rest of the same touch neither scrolls the list nor swipes the
    /// row into a reply.
    @MainActor
    func testDraggingAfterTheOverlayOpensNeitherScrollsNorSwipes() {
        // Given
        let app = launchApp(customizations: false, overlay: true)
        let latest = openFirstChannelsLatestMessage(in: app)
        let yBefore = latest.frame.minY
        let bar = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", replyBarTitle)).firstMatch

        // When: well past the swipe threshold, and down far enough to scroll to older messages.
        let start = latest.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: longPressDuration, thenDragTo: start.withOffset(CGVector(dx: swipeTravel, dy: 120)))

        // Then
        let reaction = app.buttons[overlayReaction]
        XCTAssertTrue(reaction.waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(bar.exists)

        // When
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()

        // Then
        XCTAssertTrue(reaction.waitForNonExistence(timeout: launchTimeout))
        XCTAssertEqual(latest.frame.minY, yBefore, accuracy: maxAnchorDrift)
        XCTAssertFalse(bar.exists)
    }

    /// The attachment menu offers the design source's sources and opens the system photo picker.
    ///
    /// The simulator has no camera, so Camera is not offered. Sending a picked photo is checked by
    /// `testPickingAPhotoSendsIt`.
    @MainActor
    func testAttachmentMenuOpensThePhotoPicker() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let attach = app.buttons["Attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: launchTimeout))

        // When
        attach.tap()

        // Then
        let photoLibrary = app.buttons["Photo library"]
        XCTAssertTrue(photoLibrary.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.buttons["Files"].exists)
        XCTAssertFalse(app.buttons["Camera"].exists)
        attachScreenshot(of: app, named: "Attachment menu")

        // When
        photoLibrary.tap()

        // Then
        // The system picker's labels are localised, so it is found by identifier.
        XCTAssertTrue(app.images.matching(identifier: "PXGGridLayout-Info").firstMatch.waitForExistence(timeout: launchTimeout))
        attachScreenshot(of: app, named: "Photo picker")
    }

    /// A photo picked from the library is sent and shows in the list as a sent attachment.
    ///
    /// Runs on an iOS 18 simulator, for example `-destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4'`.
    /// The iOS 26.4 simulator cannot load a picked photo (`PhotosPickerItem.loadTransferable` fails
    /// even for `Data`), so the test is skipped there.
    @MainActor
    func testPickingAPhotoSendsIt() throws {
        #if targetEnvironment(simulator)
        try XCTSkipIf(
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26,
            "The iOS 26 simulator cannot load photos picked from the library."
        )
        #endif
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(sentPhoto(in: app).exists)
        app.buttons["Attach"].tap()
        app.buttons["Photo library"].tap()
        // The system picker's labels are localised, so it is driven by identifier.
        let firstPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: launchTimeout))

        // When
        firstPhoto.tap()
        app.buttons["Add"].tap()

        // Then
        let photo = sentPhoto(in: app)
        XCTAssertTrue(photo.waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(photo.isHittable)
        XCTAssertFalse(app.alerts["Couldn't attach"].exists)
        attachScreenshot(of: app, named: "Sent photo")
    }

    /// A channel the user cannot send to shows the design source's disabled composer.
    @MainActor
    func testChannelWithoutSendingDisablesTheComposer() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[broadcastChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))

        // When
        channel.tap()

        // Then
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: launchTimeout))
        XCTAssertEqual(field.placeholderValue, unavailablePlaceholder)
        XCTAssertFalse(field.isEnabled)
        attachScreenshot(of: app, named: "Composer disabled")
    }

    /// A frozen channel explains itself with a banner above the messages.
    @MainActor
    func testFrozenChannelShowsTheBanner() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[frozenChannelName]
        XCTAssertTrue(app.staticTexts[firstChannelName].waitForExistence(timeout: launchTimeout))
        for _ in 0..<maxScrolls where !channel.isHittable {
            app.swipeUp()
        }

        // When
        channel.tap()

        // Then
        let banner = app.staticTexts[frozenBannerText]
        XCTAssertTrue(banner.waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(composerField(in: app).isEnabled)
        attachScreenshot(of: app, named: "Frozen channel")

        // When
        let firstMessage = app.staticTexts[frozenChannelCreatedMessage]
        for _ in 0..<maxScrolls where !firstMessage.isHittable {
            app.swipeDown()
        }

        // Then
        XCTAssertTrue(firstMessage.isHittable)
        XCTAssertGreaterThanOrEqual(firstMessage.frame.minY, banner.frame.maxY)
        attachScreenshot(of: app, named: "Frozen channel top")
    }

    /// A channel that can send again after a freeze gets its whole composer back.
    @MainActor
    func testComposerRecoversAfterTheChannelUnfreezes() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let attach = app.buttons["Attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: launchTimeout))
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.staticTexts[frozenBannerText].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(attach.isEnabled)

        // When
        app.buttons["Unfreeze"].tap()

        // Then
        XCTAssertTrue(app.staticTexts[frozenBannerText].waitForNonExistence(timeout: launchTimeout))
        XCTAssertTrue(composerField(in: app).isEnabled)
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: attach)
        wait(for: [enabled], timeout: launchTimeout)
        attachScreenshot(of: app, named: "Composer after unfreezing")

        // When
        attach.tap()

        // Then
        XCTAssertTrue(app.buttons["Photo library"].waitForExistence(timeout: launchTimeout))
        XCTAssertTrue(app.buttons["Files"].exists)
    }

    /// A host item sits in the screen's environment, which once kept the + button disabled after
    /// an unfreeze. The re-inserted + button is covered by
    /// `testComposerRecoversAfterTheChannelUnfreezes`.
    @MainActor
    func testComposerHostItemRecoversAfterTheChannelUnfreezes() {
        // Given
        let app = launchApp()
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let item = app.buttons[composerHostItem]
        XCTAssertTrue(item.waitForExistence(timeout: launchTimeout))
        XCTAssertLessThan(item.frame.minX, app.buttons["Attach"].frame.minX)
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.staticTexts[frozenBannerText].waitForExistence(timeout: launchTimeout))
        XCTAssertFalse(item.isEnabled)

        // When
        app.buttons["Unfreeze"].tap()

        // Then
        XCTAssertTrue(app.staticTexts[frozenBannerText].waitForNonExistence(timeout: launchTimeout))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: item)
        wait(for: [enabled], timeout: launchTimeout)
        attachScreenshot(of: app, named: "Composer host item after unfreezing")

        // When
        item.tap()

        // Then
        // The system picker's labels are localised, so it is found by identifier.
        XCTAssertTrue(app.images.matching(identifier: "PXGGridLayout-Info").firstMatch.waitForExistence(timeout: launchTimeout))
    }

    /// Sends text the sample backend fails once, and waits for the failed state.
    @MainActor
    private func sendFailingMessage(_ text: String, in app: XCUIApplication) -> XCUIElement {
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        XCTAssertTrue(app.staticTexts[firstChannelLatestMessage].waitForExistence(timeout: launchTimeout))
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: launchTimeout))
        field.tap()
        field.typeText(text)
        app.buttons["Send"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["Failed to send"].waitForExistence(timeout: launchTimeout))
        // A failed row is a button, so its text surfaces as one.
        let message = app.buttons[text]
        XCTAssertTrue(message.exists)
        return message
    }

    /// A vertical SwiftUI text field can surface as either element type.
    @MainActor
    private func composerField(in app: XCUIApplication) -> XCUIElement {
        let textView = app.textViews["Message"]
        return textView.exists ? textView : app.textFields["Message"]
    }

    /// The simulator's sample photos are JPEG or HEIC files.
    private func sentPhoto(in app: XCUIApplication) -> XCUIElement {
        let photo = NSPredicate(format: "label ENDSWITH[c] '.jpeg' OR label ENDSWITH[c] '.jpg' OR label ENDSWITH[c] '.heic'")
        return app.buttons.matching(photo).firstMatch
    }

    @MainActor
    private func openFirstChannelsLatestMessage(in app: XCUIApplication) -> XCUIElement {
        let channel = app.staticTexts[firstChannelName]
        XCTAssertTrue(channel.waitForExistence(timeout: launchTimeout))
        channel.tap()
        let latest = app.staticTexts[firstChannelLatestMessage]
        XCTAssertTrue(latest.waitForExistence(timeout: launchTimeout))
        return latest
    }

    @MainActor
    private func launchApp(
        customizations: Bool = true,
        overlay: Bool = false,
        switchDemo: Bool = false,
        hiddenHeader: Bool = false,
        questionToTop: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()

        // A simulator signed into an Apple account raises system alerts that swallow every tap.
        // Button labels are localised, so dismiss by position rather than by title.
        // XCUITest also reports the app's own modal views as interrupting alerts, the long-press
        // overlay among them; tapping their first button would close them behind the test's back.
        addUIInterruptionMonitor(withDescription: "System dialog") { alert in
            MainActor.assumeIsolated {
                guard app.alerts.count == 0, alert.buttons.count > 0 else { return false }
                alert.buttons.element(boundBy: 0).tap()
                return true
            }
        }

        app.launchEnvironment["QUICKSTART_CUSTOMIZATION_DEMO"] = customizations ? "1" : "0"
        app.launchEnvironment["QUICKSTART_OVERLAY_DEMO"] = overlay ? "1" : "0"
        app.launchEnvironment["QUICKSTART_SWITCH_DEMO"] = switchDemo ? "1" : "0"
        app.launchEnvironment["QUICKSTART_HIDDEN_HEADER_DEMO"] = hiddenHeader ? "1" : "0"
        app.launchEnvironment["QUICKSTART_QUESTION_TO_TOP_DEMO"] = questionToTop ? "1" : "0"
        app.launch()
        return app
    }

    /// The mean of a screen pixel's red, green, and blue, from 0 to 1, at a point in the app's space.
    /// `nil` when the screenshot has no image, which happens mid-transition. Not `XCTUnwrap`: it
    /// records a failure even under `try?`, so one empty frame while polling failed the test.
    @MainActor
    private func brightness(in app: XCUIApplication, at point: CGPoint) -> CGFloat? {
        guard let screen = app.screenshot().image.cgImage else { return nil }
        let scale = CGFloat(screen.width) / app.frame.width
        let pixelRect = CGRect(x: (point.x * scale).rounded(.down), y: (point.y * scale).rounded(.down), width: 1, height: 1)
        guard let pixel = screen.cropping(to: pixelRect) else { return nil }
        var rgba = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return CGFloat(Int(rgba[0]) + Int(rgba[1]) + Int(rgba[2])) / (3 * 255)
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
