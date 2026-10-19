/// Formats the numeric badges on a channel row.
nonisolated enum CountFormatter {
    /// Abbreviates a count with a K / M suffix, e.g. `999`, `1K`, `3.2K`, `1.5M`.
    static func unitString(_ count: Int) -> String {
        let units = ["", "K", "M"]
        var reduced = Double(count)
        var unitIndex = 0

        while unitIndex < units.count - 1, abs(reduced) >= 1000 {
            unitIndex += 1
            reduced /= 1000
        }

        return String(format: "%.1f", reduced)
            .replacingOccurrences(of: ".0", with: "")
            .appending(units[unitIndex])
    }

    /// The member count shown next to the title, or `nil` for a one-to-one or uncounted channel.
    static func memberCountText(_ memberCount: Int?) -> String? {
        guard let memberCount, memberCount > 2 else {
            return nil
        }
        return unitString(memberCount)
    }

    /// The unread badge text, or `nil` when there is nothing unread.
    static func unreadText(_ unreadCount: Int?) -> String? {
        guard let unreadCount, unreadCount > 0 else {
            return nil
        }
        return unreadCount > 99 ? "99+" : String(unreadCount)
    }
}
