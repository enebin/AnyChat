import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ChannelNameFormatterTests: XCTestCase {
    private enum Constant {
        static let currentUserID = "me"
        static let alice = ChatSender(id: "u1", name: "Alice")
        static let bob = ChatSender(id: "u2", name: "Bob")
        static let me = ChatSender(id: currentUserID, name: "Me")
    }

    /// A channel with a name uses it as-is.
    func testNamedChannelUsesItsOwnName() {
        // Given
        let channel = ChannelFixtures.channel {
            $0.name = "Design"
            $0.members = [Constant.alice]
        }

        // When
        let title = ChannelNameFormatter.title(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(title, "Design")
    }

    /// A channel without a name is named after the other members, in order.
    func testUnnamedChannelFallsBackToMemberNames() {
        // Given
        let channel = ChannelFixtures.channel { $0.members = [Constant.alice, Constant.bob, Constant.me] }

        // When
        let title = ChannelNameFormatter.title(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(title, "Alice, Bob")
    }

    /// A member without a name shows a placeholder rather than an empty gap.
    func testMemberWithoutNameShowsPlaceholder() {
        // Given
        let channel = ChannelFixtures.channel { $0.members = [ChatSender(id: "u1"), Constant.bob] }

        // When
        let title = ChannelNameFormatter.title(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(title, "\(ChannelNameFormatter.noName), Bob")
    }

    /// A channel holding only the current user has no one to name it after.
    func testChannelWithOnlyCurrentUserShowsNoMembers() {
        // Given
        let channel = ChannelFixtures.channel { $0.members = [Constant.me] }

        // When
        let title = ChannelNameFormatter.title(for: channel, currentUserID: Constant.currentUserID)

        // Then
        XCTAssertEqual(title, ChannelNameFormatter.noMembers)
    }
}
