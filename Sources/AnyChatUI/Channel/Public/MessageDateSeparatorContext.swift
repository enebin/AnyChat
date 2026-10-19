import Foundation

/// What the date separator above the first message of each day shows.
///
/// `day` and `time` are the default separator's texts, so a custom separator can restyle them
/// without formatting `date` again.
///
/// - Since: 1.0.0
nonisolated public struct MessageDateSeparatorContext: Sendable, Hashable {
    /// When the day's first message was sent.
    ///
    /// - Since: 1.0.0
    public var date: Date

    /// The day as the default separator writes it: "Today", "Yesterday", "Wed, Nov 15" this
    /// year, or "Nov 14, 2023" in a past year.
    ///
    /// - Since: 1.0.0
    public var day: String

    /// The time of the day's first message as the default separator writes it, such as
    /// "10:13 PM".
    ///
    /// - Since: 1.0.0
    public var time: String

    /// Creates a context, for example to preview a custom separator.
    ///
    /// - Since: 1.0.0
    public init(date: Date, day: String, time: String) {
        self.date = date
        self.day = day
        self.time = time
    }
}
