import Foundation

/// Formats the times and date separators on message rows.
///
/// Built once per row rebuild rather than once per row: `DateFormatter` is costly to create, and
/// streaming rebuilds the rows on every snapshot.
nonisolated struct MessageDateFormatter {
    static let timeFormat = "hh:mm"
    static let sameYearDateFormat = "E, MMM dd"
    static let pastYearDateFormat = "MMM dd, yyyy"
    static let separatorTimeFormat = "h:mm a"

    private let calendar: Calendar
    private let time: DateFormatter
    private let sameYearDate: DateFormatter
    private let pastYearDate: DateFormatter
    private let separatorTime: DateFormatter

    init(calendar: Calendar, locale: Locale) {
        self.calendar = calendar
        time = Self.formatter(Self.timeFormat, calendar: calendar, locale: locale)
        sameYearDate = Self.formatter(Self.sameYearDateFormat, calendar: calendar, locale: locale)
        pastYearDate = Self.formatter(Self.pastYearDateFormat, calendar: calendar, locale: locale)
        separatorTime = Self.formatter(Self.separatorTimeFormat, calendar: calendar, locale: locale)
    }

    func timeText(for date: Date) -> String {
        time.string(from: date)
    }

    /// The design source's timestamp: the day, then the time of the day's first message.
    func dateSeparator(for date: Date, now: Date) -> MessageDateSeparatorContext {
        MessageDateSeparatorContext(date: date, day: dayText(for: date, now: now), time: separatorTime.string(from: date))
    }

    private func dayText(for date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let isSameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return (isSameYear ? sameYearDate : pastYearDate).string(from: date)
    }

    private static func formatter(_ format: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }
}
