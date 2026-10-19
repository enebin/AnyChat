import Foundation
import AnyChatCore
import XCTest
@testable import AnyChatUI

final class ChannelTimeFormatterTests: XCTestCase {
    private enum Constant {
        static let locale = Locale(identifier: "en_US_POSIX")
        /// 2024-11-05 15:04:00 UTC
        static let now = Date(timeIntervalSince1970: 1_730_819_040)
        static let secondsPerDay: TimeInterval = 86_400

        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = locale
            return calendar
        }
    }

    /// A timestamp from today shows the time of day.
    func testTodayShowsTimeOfDay() {
        // Given
        let date = Constant.now.addingTimeInterval(-3_600)

        // When
        let text = makeText(date: date)

        // Then
        XCTAssertEqual(text, "02:04 PM")
    }

    /// A timestamp from the previous day is labelled rather than dated.
    func testYesterdayIsLabelled() {
        // Given
        let date = Constant.now.addingTimeInterval(-Constant.secondsPerDay)

        // When
        let text = makeText(date: date)

        // Then
        XCTAssertEqual(text, ChannelTimeFormatter.yesterday)
    }

    /// Crossing a month boundary still counts as yesterday.
    func testYesterdayAcrossMonthBoundaryIsLabelled() {
        // Given: 2024-11-01 10:00 UTC, one day after 2024-10-31
        let november1st = Date(timeIntervalSince1970: 1_730_455_200)
        let october31st = november1st.addingTimeInterval(-Constant.secondsPerDay)

        // When
        let text = ChannelTimeFormatter.text(
            for: october31st,
            now: november1st,
            calendar: Constant.calendar,
            locale: Constant.locale
        )

        // Then
        XCTAssertEqual(text, ChannelTimeFormatter.yesterday)
    }

    /// An older date in the same year shows month and day.
    func testEarlierThisYearShowsMonthAndDay() {
        // Given
        let date = Constant.now.addingTimeInterval(-Constant.secondsPerDay * 30)

        // When
        let text = makeText(date: date)

        // Then
        XCTAssertEqual(text, "Oct 06")
    }

    /// A date from a previous year shows the full date.
    func testPreviousYearShowsFullDate() {
        // Given
        let date = Constant.now.addingTimeInterval(-Constant.secondsPerDay * 400)

        // When
        let text = makeText(date: date)

        // Then
        XCTAssertEqual(text, "2023/10/02")
    }

    /// A channel with no timestamp at all shows nothing.
    func testEpochHasNoText() {
        // Given / When
        let text = makeText(date: Date(timeIntervalSince1970: 0))

        // Then
        XCTAssertNil(text)
    }

    /// The last message time wins over the channel creation time.
    func testLastMessageTimeIsPreferred() {
        // Given
        let channel = ChannelFixtures.channel { $0.lastMessage = ChannelFixtures.message(createdAt: Constant.now) }

        // When
        let date = ChannelTimeFormatter.baseDate(for: channel)

        // Then
        XCTAssertEqual(date, Constant.now)
    }

    /// Without messages the channel creation time is used.
    func testChannelCreationTimeIsUsedWhenThereAreNoMessages() {
        // Given
        let channel = ChannelFixtures.channel()

        // When
        let date = ChannelTimeFormatter.baseDate(for: channel)

        // Then
        XCTAssertEqual(date, ChannelFixtures.createdAt)
    }

    private func makeText(date: Date) -> String? {
        ChannelTimeFormatter.text(
            for: date,
            now: Constant.now,
            calendar: Constant.calendar,
            locale: Constant.locale
        )
    }
}
