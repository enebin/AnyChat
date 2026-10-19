import AnyChatCore

/// Builds the title shown on a channel row.
nonisolated enum ChannelNameFormatter {
    static let noMembers = "(No members)"
    static let noName = "(No name)"

    /// Returns the channel name, or a name built from the other members when it has none.
    static func title(for channel: ChatChannel, currentUserID: String?) -> String {
        channel.name ?? membersTitle(for: channel, currentUserID: currentUserID)
    }

    private static func membersTitle(for channel: ChatChannel, currentUserID: String?) -> String {
        let others = channel.members.filter { $0.id != currentUserID }
        guard !others.isEmpty else {
            return noMembers
        }
        return others
            .map { $0.name ?? noName }
            .joined(separator: ", ")
    }
}
