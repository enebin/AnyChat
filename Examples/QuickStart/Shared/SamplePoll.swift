/// An app-defined message value. A screen that registers a renderer for it draws a poll card;
/// anywhere else shows the message's text fallback.
nonisolated struct SamplePoll: Hashable, Sendable {
    struct Option: Hashable, Sendable {
        let title: String
        let votes: Int
    }

    let question: String
    let options: [Option]
}
