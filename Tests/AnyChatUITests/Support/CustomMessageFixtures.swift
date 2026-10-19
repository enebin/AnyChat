enum CustomMessageFixtures {
    struct Thinking: Hashable, Sendable {
        let text: String
    }

    struct Response: Hashable, Sendable {
        let text: String
    }

    struct Moderation: Hashable, Sendable {
        let isReported: Bool
    }

    static let thinking = Thinking(text: "Working")
    static let updatedThinking = Thinking(text: "Finished")
    static let response = Response(text: "Answer")
    static let reported = Moderation(isReported: true)
    static let unreported = Moderation(isReported: false)
}
