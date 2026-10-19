import Foundation
import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ChannelRowStateTests: XCTestCase {
    private enum Constant {
        static let currentUserID = "me"
        static let now = Date(timeIntervalSince1970: 1_730_819_040)
        static let coverURL = URL(string: "https://example.com/cover.png")!
        static let aliceImageURL = URL(string: "https://example.com/alice.png")!
        static let me = ChatSender(id: currentUserID, name: "Me")
        static let alice = ChatSender(id: "u1", name: "Alice", profileImageURL: aliceImageURL)
        static let bob = ChatSender(id: "u2", name: "Bob")
    }

    /// A cover URL wins over everything else.
    func testCoverURLIsUsedWhenPresent() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.coverURL = Constant.coverURL
            $0.members = [Constant.alice]
            $0.isBroadcast = true
        }

        // When
        let cover = ChannelCover.resolve(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(cover, .url(Constant.coverURL))
    }

    /// Without a cover, the other members' pictures are composited, keeping gaps for missing ones.
    func testChannelWithoutCoverUsesMemberAvatars() {
        // Given
        let channel = ChannelFixtures.channel { $0.members = [Constant.me, Constant.alice, Constant.bob] }

        // When
        let cover = ChannelCover.resolve(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(
            cover,
            .members([
                .init(userID: "u1", profileImageURL: Constant.aliceImageURL),
                .init(userID: "u2", profileImageURL: nil)
            ])
        )
    }

    /// A broadcast channel without a cover shows its own icon.
    func testBroadcastChannelWithoutCoverUsesBroadcastIcon() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.members = [Constant.alice]
            $0.isBroadcast = true
        }

        // When
        let cover = ChannelCover.resolve(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(cover, .broadcast)
    }

    /// A channel holding only the current user has no avatar to show.
    func testChannelWithOnlyCurrentUserUsesPlaceholder() {
        // Given
        let channel = ChannelFixtures.channel { $0.members = [Constant.me] }

        // When
        let cover = ChannelCover.resolve(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(cover, .placeholder)
    }

    /// The group avatar holds at most four faces.
    func testMemberAvatarsAreCappedAtFour() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.members = (1...6).map { ChatSender(id: "u\($0)", name: "User \($0)") }
        }

        // When
        let cover = ChannelCover.resolve(for: channel, currentUserID: Constant.currentUserID)

        // Then
        guard case let .members(avatars) = cover else {
            return XCTFail("expected member avatars, got \(cover)")
        }
        XCTAssertEqual(avatars.count, ChannelCover.maxAvatarCount)
    }

    /// A derived row carries everything the view needs in one value.
    func testRowIsDerivedFromChannel() {
        // Given
        let channel = ChannelFixtures.channel(id: "channel_1") {
            $0.name = "Design"
            $0.members = [Constant.alice, Constant.bob, Constant.me]
            $0.memberCount = 3
            $0.unreadMessageCount = 120
            $0.unreadMentionCount = 1
            $0.notificationLevel = .off
            $0.isFrozen = true
            $0.canLeave = true
            $0.lastMessage = ChannelFixtures.message(.text("Ship it"), senderID: "u1")
        }

        // When
        let row = ChannelRowState.make(
            channel: channel,
            currentUserID: Constant.currentUserID,
            now: Constant.now,
            options: ChannelListOptions(isMentionBadgeEnabled: true)
        )

        // Then
        XCTAssertEqual(row.id, "channel_1")
        XCTAssertEqual(row.title, "Design")
        XCTAssertEqual(row.memberCountText, "3")
        XCTAssertEqual(row.unreadCountText, "99+")
        XCTAssertTrue(row.showsUnreadMention)
        XCTAssertTrue(row.isNotificationOff)
        XCTAssertTrue(row.isFrozen)
        XCTAssertFalse(row.isBroadcast)
        XCTAssertTrue(row.canLeave)
        XCTAssertTrue(row.canToggleNotifications)
        XCTAssertEqual(row.previewText, "Ship it")
        XCTAssertFalse(row.isActionPending)
    }

    /// A channel that cannot be left or muted offers neither swipe action.
    func testChannelWithoutCapabilitiesOffersNoActions() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.canLeave = false
            $0.notificationLevel = nil
        }

        // When
        let row = ChannelRowState.make(
            channel: channel,
            currentUserID: Constant.currentUserID,
            now: Constant.now,
            options: ChannelListOptions()
        )

        // Then
        XCTAssertFalse(row.canLeave)
        XCTAssertFalse(row.canToggleNotifications)
        XCTAssertFalse(row.isNotificationOff)
    }

    /// The mention mark stays hidden while the option is off, even with unread mentions.
    func testMentionMarkIsHiddenWhenOptionIsDisabled() {
        // Given
        let channel = ChannelFixtures.channel { $0.unreadMentionCount = 3 }

        // When
        let row = ChannelRowState.make(
            channel: channel,
            currentUserID: Constant.currentUserID,
            now: Constant.now,
            options: ChannelListOptions()
        )

        // Then
        XCTAssertFalse(row.showsUnreadMention)
    }

    /// Rows derived from equal channels compare equal, which is what drives list diffing.
    func testRowsWithSameContentAreEqual() {
        // Given
        let makeChannel = { ChannelFixtures.channel(id: "channel_1") { $0.name = "Design" } }
        let options = ChannelListOptions()

        // When
        let first = ChannelRowState.make(
            channel: makeChannel(),
            currentUserID: Constant.currentUserID,
            now: Constant.now,
            options: options
        )
        let second = ChannelRowState.make(
            channel: makeChannel(),
            currentUserID: Constant.currentUserID,
            now: Constant.now,
            options: options
        )

        // Then
        XCTAssertEqual(first, second)
    }
}
