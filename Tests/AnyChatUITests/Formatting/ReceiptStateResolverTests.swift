import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ReceiptStateResolverTests: XCTestCase {
    private enum Constant {
        static let currentUserID = "me"
        static let enabled = ChannelListOptions(isMessageReceiptStatusEnabled: true)
        static let disabled = ChannelListOptions(isMessageReceiptStatusEnabled: false)
    }

    /// The receipt icon is off by default.
    func testDisabledOptionHidesReceipt() {
        // Given
        let channel = channel(lastMessageFrom: Constant.currentUserID, receipt: .read)

        // When
        let receipt = ReceiptStateResolver.receipt(
            for: channel,
            currentUserID: Constant.currentUserID,
            options: Constant.disabled
        )

        // Then
        XCTAssertNil(receipt)
    }

    /// Messages from other people never show a receipt.
    func testMessageFromSomeoneElseHidesReceipt() {
        // Given
        let channel = channel(lastMessageFrom: "someone_else", receipt: .read)

        // When
        let receipt = ReceiptStateResolver.receipt(
            for: channel,
            currentUserID: Constant.currentUserID,
            options: Constant.enabled
        )

        // Then
        XCTAssertNil(receipt)
    }

    /// A channel with no messages has nothing to report on.
    func testChannelWithoutMessagesHidesReceipt() {
        // Given
        let channel = ChannelFixtures.channel()

        // When
        let receipt = ReceiptStateResolver.receipt(
            for: channel,
            currentUserID: Constant.currentUserID,
            options: Constant.enabled
        )

        // Then
        XCTAssertNil(receipt)
    }

    /// The current user's own message shows whatever receipt the backend reported, including none.
    func testOwnMessageShowsItsReceipt() {
        // Given
        let delivered = channel(lastMessageFrom: Constant.currentUserID, receipt: .delivered)
        let untracked = channel(lastMessageFrom: Constant.currentUserID, receipt: nil)

        // When / Then
        XCTAssertEqual(
            ReceiptStateResolver.receipt(for: delivered, currentUserID: Constant.currentUserID, options: Constant.enabled),
            .delivered
        )
        XCTAssertNil(
            ReceiptStateResolver.receipt(for: untracked, currentUserID: Constant.currentUserID, options: Constant.enabled)
        )
    }

    private func channel(lastMessageFrom senderID: String, receipt: ChatMessage.Receipt?) -> ChatChannel {
        ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(senderID: senderID, receipt: receipt) }
    }
}
