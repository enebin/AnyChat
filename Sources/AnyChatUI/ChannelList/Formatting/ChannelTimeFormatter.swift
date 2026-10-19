import Foundation
import AnyChatCore

/// Formats the "last updated" timestamp on a channel row.
nonisolated enum ChannelTimeFormatter {
    static let yesterday = "Yesterday"
    static let timeFormat = "hh:mm a"
    static let sameYearFormat = "MMM dd"
    static let pastYearFormat = "yyyy/MM/dd"

    /// Returns the row timestamp, based on the last message when there is one.
    static func lastUpdatedText(
        for channel: ChatChannel,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        text(for: baseDate(for: channel), now: now, calendar: calendar, locale: locale)
    }

    static func baseDate(for channel: ChatChannel) -> Date {
        channel.lastMessage?.createdAt ?? channel.createdAt
    }

    /// Returns `nil` for dates at or before the Unix epoch, which mean "no time recorded".
    static func text(
        for date: Date,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        guard date.timeIntervalSince1970 > 0 else {
            return nil
        }

        if calendar.isDate(date, inSameDayAs: now) {
            return string(from: date, format: timeFormat, calendar: calendar, locale: locale)
        }

        if let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterdayDate) {
            return yesterday
        }

        let isSameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let format = isSameYear ? sameYearFormat : pastYearFormat
        return string(from: date, format: format, calendar: calendar, locale: locale)
    }

    private static func string(from date: Date, format: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
