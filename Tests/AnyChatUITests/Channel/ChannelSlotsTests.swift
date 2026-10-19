import SwiftUI
import AnyChatCore
import XCTest
@testable import AnyChatUI

@MainActor
final class ChannelSlotsTests: XCTestCase {
    private enum Renderer {
        case first, last, fallback
    }

    private let context = MessageRowContext(isMine: false, groupPosition: .single)

    func testContentRenderersReceiveTheirOwnValueTypeAndMessageContext() {
        // Given
        var capturedThinking: CustomMessageFixtures.Thinking?
        var capturedResponse: CustomMessageFixtures.Response?
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageContent(CustomMessageFixtures.Thinking.self) { value, message, context in
                capturedThinking = value
                capturedMessage = message
                capturedContext = context
                return EmptyView()
            }
            .messageContent(CustomMessageFixtures.Response.self) { value, _, _ in
                capturedResponse = value
                return EmptyView()
            }
        let thinking = message(with: CustomMessageFixtures.thinking)
        let response = message(with: CustomMessageFixtures.response)

        // When
        let thinkingView = view.slots.content(for: thinking, context: context)
        let responseView = view.slots.content(for: response, context: context)

        // Then
        XCTAssertNotNil(thinkingView)
        XCTAssertNotNil(responseView)
        XCTAssertEqual(capturedThinking, CustomMessageFixtures.thinking)
        XCTAssertEqual(capturedResponse, CustomMessageFixtures.response)
        XCTAssertEqual(capturedMessage, thinking)
        XCTAssertEqual(capturedContext, context)
    }

    func testWholeRowRendererReceivesTheMatchingCustomValue() {
        // Given
        var capturedValue: CustomMessageFixtures.Thinking?
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Thinking.self) { value, message, context in
                capturedValue = value
                capturedMessage = message
                capturedContext = context
                return EmptyView()
            }
        let customMessage = message(with: CustomMessageFixtures.thinking)

        // When
        let row = view.slots.row(for: customMessage, context: context)

        // Then
        XCTAssertNotNil(row)
        XCTAssertEqual(capturedValue, CustomMessageFixtures.thinking)
        XCTAssertEqual(capturedMessage, customMessage)
        XCTAssertEqual(capturedContext, context)
    }

    func testAttributesDoNotChangeWhichTypedRendererMatches() {
        // Given
        var capturedValue: CustomMessageFixtures.Thinking?
        var capturedMessage: ChatMessage?
        var customMessage = message(with: CustomMessageFixtures.thinking)
        customMessage.attributes[CustomMessageFixtures.Moderation.self] = CustomMessageFixtures.reported
        customMessage.attributes[CustomMessageFixtures.Response.self] = CustomMessageFixtures.response
        let attributeTypeOnly = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Response.self) { _, _, _ in EmptyView() }
            .messageContent(CustomMessageFixtures.Response.self) { _, _, _ in EmptyView() }
        let customType = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Thinking.self) { value, message, _ in
                capturedValue = value
                capturedMessage = message
                return EmptyView()
            }

        // When
        let attributeTypeRow = attributeTypeOnly.slots.row(for: customMessage, context: context)
        let attributeTypeContent = attributeTypeOnly.slots.content(for: customMessage, context: context)
        let customTypeRow = customType.slots.row(for: customMessage, context: context)

        // Then
        XCTAssertNil(attributeTypeRow)
        XCTAssertNil(attributeTypeContent)
        XCTAssertNotNil(customTypeRow)
        XCTAssertEqual(capturedValue, CustomMessageFixtures.thinking)
        XCTAssertEqual(capturedMessage?.attributes[CustomMessageFixtures.Moderation.self], CustomMessageFixtures.reported)
    }

    func testLastMatchingContentRendererWinsBeforeTheUntypedSlot() {
        // Given
        var calls: [Renderer] = []
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageContent(CustomMessageFixtures.Thinking.self) { _, _, _ in
                calls.append(.first)
                return EmptyView()
            }
            .messageContent(CustomMessageFixtures.Thinking.self) { _, _, _ in
                calls.append(.last)
                return EmptyView()
            }
            .messageContent { _, _ in
                calls.append(.fallback)
                return EmptyView()
            }

        // When
        let content = view.slots.content(for: message(with: CustomMessageFixtures.thinking), context: context)

        // Then
        XCTAssertNotNil(content)
        XCTAssertEqual(calls, [.last])
    }

    func testLastMatchingRowRendererWinsBeforeTheUntypedSlot() {
        // Given
        var calls: [Renderer] = []
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Thinking.self) { _, _, _ in
                calls.append(.first)
                return EmptyView()
            }
            .messageRow(CustomMessageFixtures.Thinking.self) { _, _, _ in
                calls.append(.last)
                return EmptyView()
            }
            .messageRow { _, _ in
                calls.append(.fallback)
                return EmptyView()
            }

        // When
        let row = view.slots.row(for: message(with: CustomMessageFixtures.thinking), context: context)

        // Then
        XCTAssertNotNil(row)
        XCTAssertEqual(calls, [.last])
    }

    func testUnmatchedTypesAndOrdinaryMessagesUseUntypedSlots() {
        // Given
        var rowCalls = 0
        var contentCalls = 0
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
            .messageContent(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
            .messageRow { _, _ in
                rowCalls += 1
                return EmptyView()
            }
            .messageContent { _, _ in
                contentCalls += 1
                return EmptyView()
            }
        let messages = [message(with: CustomMessageFixtures.response), MessageFixtures.message("ordinary")]

        // When
        for message in messages {
            XCTAssertNotNil(view.slots.row(for: message, context: context))
            XCTAssertNotNil(view.slots.content(for: message, context: context))
        }

        // Then
        XCTAssertEqual(rowCalls, messages.count)
        XCTAssertEqual(contentCalls, messages.count)
    }

    func testUnmatchedTypesWithoutUntypedSlotsFallBackToDefaultViews() {
        // Given
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageRow(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
            .messageContent(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
        let messages = [message(with: CustomMessageFixtures.response), MessageFixtures.message("ordinary")]

        // When
        let rows = messages.map { view.slots.row(for: $0, context: context) }
        let contents = messages.map { view.slots.content(for: $0, context: context) }

        // Then
        XCTAssertTrue(rows.allSatisfy { $0 == nil })
        XCTAssertTrue(contents.allSatisfy { $0 == nil })
    }

    func testRegistrationsBelongToOneChannelViewInstance() {
        // Given
        let original = ChannelView(channel: ChannelFixtures.channel())
        let customized = original
            .messageRow(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
            .messageContent(CustomMessageFixtures.Thinking.self) { _, _, _ in EmptyView() }
        let customMessage = message(with: CustomMessageFixtures.thinking)

        // When
        let originalRow = original.slots.row(for: customMessage, context: context)
        let originalContent = original.slots.content(for: customMessage, context: context)
        let customizedRow = customized.slots.row(for: customMessage, context: context)
        let customizedContent = customized.slots.content(for: customMessage, context: context)

        // Then
        XCTAssertNil(originalRow)
        XCTAssertNil(originalContent)
        XCTAssertNotNil(customizedRow)
        XCTAssertNotNil(customizedContent)
    }

    func testSlotsReceiveTheRowsOriginalBodyAttachmentsAndHiddenSender() {
        // Given
        let sender = ChatSender(id: "me", name: "Me")
        let message = ChatMessage(
            id: "mixed", sender: sender, createdAt: MessageFixtures.start,
            text: "The photo and report", attachments: [AttachmentFixtures.image, AttachmentFixtures.document],
            customContent: CustomMessageFixtures.thinking
        )
        let row = MessageRowState.rows(for: [message], currentUserID: sender.id, now: MessageFixtures.start)[0]
        var capturedRowMessage: ChatMessage?
        var capturedContentMessage: ChatMessage?
        var capturedValue: CustomMessageFixtures.Thinking?
        var capturedContext: MessageRowContext?
        let view = ChannelView(channel: ChannelFixtures.channel())
            .messageRow { message, _ in
                capturedRowMessage = message
                return EmptyView()
            }
            .messageContent(CustomMessageFixtures.Thinking.self) { value, message, context in
                capturedValue = value
                capturedContentMessage = message
                capturedContext = context
                return EmptyView()
            }

        // When
        let rowView = view.slots.row(for: row.message, context: row.context)
        let contentView = view.slots.content(for: row.message, context: row.context)

        // Then
        XCTAssertNotNil(rowView)
        XCTAssertNotNil(contentView)
        XCTAssertFalse(row.showsSenderName)
        XCTAssertEqual(capturedRowMessage, message)
        XCTAssertEqual(capturedContentMessage, message)
        XCTAssertEqual(capturedValue, CustomMessageFixtures.thinking)
        XCTAssertEqual(capturedContext, row.context)
    }

    func testAttachmentSelectionReachesTheHostWithItsMessage() {
        // Given
        let message = ChatMessage(id: "photo", createdAt: MessageFixtures.start, attachments: [AttachmentFixtures.image])
        var selected: (ChatAttachment, ChatMessage)?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let listening = plain.onAttachmentSelected { selected = ($0, $1) }

        // When
        listening.slots.attachmentSelected?(AttachmentFixtures.image, message)

        // Then
        XCTAssertNil(plain.slots.attachmentSelected)
        XCTAssertEqual(selected?.0, AttachmentFixtures.image)
        XCTAssertEqual(selected?.1, message)
    }

    private func message<Value: Hashable & Sendable>(with value: Value) -> ChatMessage {
        ChatMessage(id: "custom", createdAt: MessageFixtures.start, customContent: value)
    }

    func testDoubleTapIsStoredOnTheViewInstance() {
        // Given
        let view = ChannelView(channel: ChannelFixtures.channel())
            .onMessageDoubleTapped { _, _ in }

        // Then
        XCTAssertNotNil(view.slots.messageDoubleTapped)
        XCTAssertNil(ChannelView(channel: ChannelFixtures.channel()).slots.messageDoubleTapped)
    }

    func testReplyQuoteIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        var message = message(with: CustomMessageFixtures.thinking)
        message.replyTo = .unavailable(messageID: "original")
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageReplyQuote { message, context in
            capturedMessage = message
            capturedContext = context
            return EmptyView()
        }

        // When
        let quote = decorated.slots.messageReplyQuote?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageReplyQuote)
        XCTAssertNotNil(quote)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testReplyBarIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let decorated = plain.composerReplyBar { _, _ in EmptyView() }

        // Then
        XCTAssertNil(plain.slots.composerReplyBar)
        XCTAssertNotNil(decorated.slots.composerReplyBar)
    }

    func testAccessoryIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        var message = message(with: CustomMessageFixtures.thinking)
        message.attributes[CustomMessageFixtures.Moderation.self] = CustomMessageFixtures.reported
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageAccessory { message, context in
            capturedMessage = message
            capturedContext = context
            return EmptyView()
        }

        // When
        let accessory = decorated.slots.messageAccessory?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageAccessory)
        XCTAssertNotNil(accessory)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testBubbleBackgroundIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        let message = message(with: CustomMessageFixtures.thinking)
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageBubbleBackground { message, context in
            capturedMessage = message
            capturedContext = context
            return Color.clear
        }

        // When
        let background = decorated.slots.messageBubbleBackground?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageBubbleBackground)
        XCTAssertNotNil(background)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testBubbleLayoutIsStoredOnTheViewInstanceAndKeepsWhatALaterCallLeavesOut() {
        // Given
        let insets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let maxWidth: CGFloat = 280
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let insetsOnly = plain.messageBubbleLayout(insets: insets)
        let both = insetsOnly.messageBubbleLayout(maxWidth: maxWidth)

        // Then
        XCTAssertEqual(plain.slots.messageBubbleLayout, ChannelSlots.MessageBubbleLayout())
        XCTAssertEqual(insetsOnly.slots.messageBubbleLayout, ChannelSlots.MessageBubbleLayout(insets: insets))
        XCTAssertEqual(both.slots.messageBubbleLayout, ChannelSlots.MessageBubbleLayout(insets: insets, maxWidth: maxWidth))
    }

    func testAvatarIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        let message = message(with: CustomMessageFixtures.thinking)
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageAvatar { message, context in
            capturedMessage = message
            capturedContext = context
            return Circle()
        }

        // When
        let avatar = decorated.slots.messageAvatar?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageAvatar)
        XCTAssertNotNil(avatar)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testSenderNameIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        let message = message(with: CustomMessageFixtures.thinking)
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageSenderName { message, context in
            capturedMessage = message
            capturedContext = context
            return Text("Name")
        }

        // When
        let name = decorated.slots.messageSenderName?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageSenderName)
        XCTAssertNotNil(name)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testTimeIsStoredOnTheViewInstanceAndReceivesTheMessageAndContext() {
        // Given
        let message = message(with: CustomMessageFixtures.thinking)
        var capturedMessage: ChatMessage?
        var capturedContext: MessageRowContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageTime { message, context in
            capturedMessage = message
            capturedContext = context
            return Text("Now")
        }

        // When
        let time = decorated.slots.messageTime?(message, context)

        // Then
        XCTAssertNil(plain.slots.messageTime)
        XCTAssertNotNil(time)
        XCTAssertEqual(capturedMessage, message)
        XCTAssertEqual(capturedContext, context)
    }

    func testDateSeparatorIsStoredOnTheViewInstanceAndReceivesItsContext() {
        // Given
        let separator = MessageDateSeparatorContext(date: Date(timeIntervalSince1970: 0), day: "Today", time: "10:13 PM")
        var capturedSeparator: MessageDateSeparatorContext?
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let decorated = plain.messageDateSeparator { separator in
            capturedSeparator = separator
            return Text(separator.day)
        }

        // When
        let view = decorated.slots.messageDateSeparator?(separator)

        // Then
        XCTAssertNil(plain.slots.messageDateSeparator)
        XCTAssertNotNil(view)
        XCTAssertEqual(capturedSeparator, separator)
    }

    func testComposerPlaceholderIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain.composerPlaceholder("Message…")

        // Then
        XCTAssertNil(plain.slots.composerPlaceholder)
        XCTAssertEqual(customized.slots.composerPlaceholder, "Message…")
    }

    func testComposerItemsAreStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain
            .composerLeadingItems { context in context.defaultItems }
            .composerTrailingItems { _ in EmptyView() }

        // Then
        XCTAssertNil(plain.slots.composerLeadingItems)
        XCTAssertNil(plain.slots.composerTrailingItems)
        XCTAssertNotNil(customized.slots.composerLeadingItems)
        XCTAssertNotNil(customized.slots.composerTrailingItems)
    }

    func testComposerItemsInsideFieldIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain.composerItemsInsideField()

        // Then
        XCTAssertFalse(plain.slots.composerItemsInsideField)
        XCTAssertTrue(customized.slots.composerItemsInsideField)
    }

    func testComposerSendButtonLabelIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain.composerSendButtonLabel { Text("Send") }

        // Then
        XCTAssertNil(plain.slots.composerSendButtonLabel)
        XCTAssertNotNil(customized.slots.composerSendButtonLabel)
    }

    func testComposerStopButtonIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())
        var stops = 0

        // When
        let customized = plain.composerStopButton(isResponding: true) { stops += 1 }
        customized.slots.composerStopButton?.action()

        // Then
        XCTAssertNil(plain.slots.composerStopButton)
        XCTAssertEqual(customized.slots.composerStopButton?.isResponding, true)
        XCTAssertEqual(stops, 1)
    }

    /// The host passes its state on every update, so a later call replaces the earlier one.
    func testLaterComposerStopButtonReplacesTheEarlierOne() {
        // Given
        let active = ChannelView(channel: ChannelFixtures.channel())
            .composerStopButton(isResponding: true) {}

        // When
        let idle = active.composerStopButton(isResponding: false) {}

        // Then
        XCTAssertEqual(idle.slots.composerStopButton?.isResponding, false)
    }

    func testEmptyStateIsStoredOnTheViewInstanceAndReceivesTheComposerContext() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())
        let presentation = ComposerPresentation()
        presentation.isEnabled = true
        var capturedCanSend: Bool?

        // When
        let customized = plain.channelEmptyState { composer in
            capturedCanSend = composer.canSend
            return EmptyView()
        }
        let view = customized.slots.emptyState?(presentation.context(showsAttachButton: false))

        // Then
        XCTAssertNil(plain.slots.emptyState)
        XCTAssertNotNil(view)
        XCTAssertEqual(capturedCanSend, true)
    }

    func testComposerIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain.composer { _ in EmptyView() }

        // Then
        XCTAssertNil(plain.slots.composer)
        XCTAssertNotNil(customized.slots.composer)
    }

    func testComposerBackgroundIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())
        var builds = 0

        // When
        let customized = plain.composerBackground {
            builds += 1
            return Color.clear
        }
        let view = customized.slots.composerBackground?()

        // Then
        XCTAssertNil(plain.slots.composerBackground)
        XCTAssertNotNil(view)
        XCTAssertEqual(builds, 1)
    }

    func testJumpToLatestButtonIsStoredOnTheViewInstanceAndReceivesTheAction() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())
        var jumps = 0
        var capturedJump: (() -> Void)?

        // When
        let customized = plain.jumpToLatestButton { jump in
            capturedJump = jump
            return Button("Latest", action: jump)
        }
        let view = customized.slots.jumpToLatestButton? { jumps += 1 }
        capturedJump?()

        // Then
        XCTAssertNil(plain.slots.jumpToLatestButton)
        XCTAssertNotNil(view)
        XCTAssertEqual(jumps, 1)
    }

    func testScrollBehaviorDefaultsToFollowingTheLatestAndIsStoredOnTheViewInstance() {
        // Given
        let plain = ChannelView(channel: ChannelFixtures.channel())

        // When
        let customized = plain.messageScrollBehavior(.questionToTop)

        // Then
        XCTAssertEqual(plain.slots.scrollBehavior, .followsLatest)
        XCTAssertEqual(customized.slots.scrollBehavior, .questionToTop)
    }
}
