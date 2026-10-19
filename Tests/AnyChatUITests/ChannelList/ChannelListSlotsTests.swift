import SwiftUI
import XCTest
@testable import AnyChatUI

@MainActor
final class ChannelListSlotsTests: XCTestCase {
    func testListHeaderIsStoredOnTheViewInstance() {
        // Given
        var callCount = 0
        let plain = ChannelListView()
        let decorated = plain.channelListHeader {
            callCount += 1
            return Text("Notes")
        }

        // When
        let header = decorated.slots.listHeader?()

        // Then
        XCTAssertNil(plain.slots.listHeader)
        XCTAssertNotNil(header)
        XCTAssertEqual(callCount, 1)
    }
}
