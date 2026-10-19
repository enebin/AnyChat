/// App state a sample message carries in `ChatMessage.attributes`: reaction counts in display
/// order. A screen that registers a message accessory draws them below the bubble; each draws them
/// its own way.
nonisolated struct SampleReactions: Hashable, Sendable {
    struct Reaction: Hashable, Sendable {
        let emoji: String
        /// Read by VoiceOver, and by the UI tests, in place of the emoji.
        let name: String
        let count: Int
    }

    let reactions: [Reaction]
}
