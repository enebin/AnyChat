import Foundation
import AnyChatUI

/// A canned answer: Markdown text, plus images it shows with `![alt](file name)` lines.
nonisolated struct LumenReply: Hashable, Sendable {
    var text: String
    var attachments: [ChatAttachment] = []
}

nonisolated enum LumenReplies {
    struct Chat {
        var channel: ChatChannel
        var messages: [ChatMessage]
    }

    static let suggestions: [(title: String, detail: String, prompt: String)] = [
        ("Plan a weekend trip", "to somewhere close by", "Plan a weekend trip to somewhere close by"),
        ("Explain a concept", "like I'm sixteen", "Explain compound interest like I'm sixteen"),
        ("Write a recipe", "with what's in my fridge", "Help me make a cafe mocha at home"),
        ("Help me code", "a small Swift function", "Write a Swift function that reverses words in a sentence"),
    ]

    /// Picks an answer from the question's words. `variant` gives a regenerated answer a different text.
    static func reply(to question: ChatMessage, mode: ToolMode?, variant: Int = 0) -> LumenReply {
        if !question.attachments.isEmpty {
            return LumenReply(text: photo)
        }
        let text = question.plainText.lowercased()
        switch mode {
        case .createImage:
            return LumenReply(text: image, attachments: [media("landscape", "jpg")])
        case .webSearch:
            return LumenReply(text: search)
        case .thinkLonger, nil:
            break
        }
        let topic = topics.first { $0.keywords.contains { text.contains($0) } }
        let answers = topic?.answers ?? [fallback(question.plainText)]
        var reply = answers[variant % answers.count]
        if topic?.keywords.first == "mocha" {
            reply.attachments = [media("portrait", "jpg"), media("landscape", "jpg")]
        }
        return reply
    }

    /// A short chat title from the first message, like a drawer row would show it.
    static func title(for text: String) -> String {
        let lower = text.lowercased()
        if let topic = topics.first(where: { topic in topic.keywords.contains { lower.contains($0) } }) {
            return topic.title
        }
        let words = text.split(separator: " ").prefix(5).joined(separator: " ")
        return words.isEmpty ? "New chat" : words
    }

    /// The answer split into words, each with the spaces and line breaks after it.
    static func words(of text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in text {
            if !character.isWhitespace, let last = current.last, last.isWhitespace {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }

    static func history(now: Date) -> [Chat] {
        [
            chat(
                id: "trip",
                title: "Weekend trip near Busan",
                at: now.addingTimeInterval(-3_600 * 3),
                question: "Plan a weekend trip near Busan",
                answer: trip
            ),
            chat(
                id: "swift",
                title: "Swift concurrency questions",
                at: now.addingTimeInterval(-86_400 * 2),
                question: "What does @MainActor do on a class?",
                answer: mainActor
            ),
            chat(
                id: "birthday",
                title: "Birthday message for a friend",
                at: now.addingTimeInterval(-86_400 * 4),
                question: "Write a short birthday message for my friend Sam",
                answer: birthday
            ),
            chat(
                id: "interest",
                title: "Explain compound interest",
                at: now.addingTimeInterval(-86_400 * 6),
                question: "Explain compound interest like I'm sixteen",
                answer: interest
            ),
        ]
    }

    private static func chat(id: String, title: String, at date: Date, question: String, answer: String) -> Chat {
        let asked = ChatMessage(id: "\(id)-q", sender: LumenBackend.me, createdAt: date, content: .text(question))
        let answered = ChatMessage(
            id: "\(id)-a",
            sender: LumenBackend.assistant,
            createdAt: date.addingTimeInterval(5),
            content: .text(answer),
            customContent: Answer(phase: .done)
        )
        let channel = ChatChannel(
            id: id,
            name: title,
            createdAt: date,
            members: [LumenBackend.me, LumenBackend.assistant],
            lastMessage: answered,
            canLeave: true
        )
        return Chat(channel: channel, messages: [asked, answered])
    }

    private static func media(_ name: String, _ ext: String) -> ChatAttachment {
        ChatAttachment(
            id: "\(name).\(ext)",
            kind: .image,
            url: Bundle.main.url(forResource: name, withExtension: ext) ?? URL(fileURLWithPath: "/dev/null"),
            fileName: "\(name).\(ext)"
        )
    }

    private struct Topic {
        var keywords: [String]
        var title: String
        var answers: [LumenReply]
    }

    private static let topics: [Topic] = [
        Topic(keywords: ["mocha", "coffee", "cafe", "café", "fridge", "recipe"], title: "Cafe mocha at home", answers: [
            LumenReply(text: mocha), LumenReply(text: mochaShort),
        ]),
        Topic(keywords: ["trip", "travel", "weekend"], title: "Weekend trip plan", answers: [
            LumenReply(text: trip), LumenReply(text: tripShort),
        ]),
        Topic(keywords: ["interest", "explain", "concept"], title: "Explain compound interest", answers: [
            LumenReply(text: interest), LumenReply(text: interestShort),
        ]),
        Topic(keywords: ["actor", "concurrency"], title: "Swift concurrency questions", answers: [
            LumenReply(text: mainActor), LumenReply(text: mainActorShort),
        ]),
        Topic(keywords: ["swift", "code", "function"], title: "Reverse words in Swift", answers: [
            LumenReply(text: code), LumenReply(text: codeShort),
        ]),
        Topic(keywords: ["birthday", "message for"], title: "Birthday message", answers: [
            LumenReply(text: birthday),
        ]),
    ]

    private static func fallback(_ question: String) -> LumenReply {
        LumenReply(text: """
        Good question. This demo answers from a few prepared replies, so here is a general one.

        - Try asking about a **recipe**, a **weekend trip**, **compound interest**, or **Swift code**.
        - Or pick a tool from the **+** menu to see a different kind of answer.

        You asked: *\(question)*
        """)
    }
}

// MARK: - Texts

nonisolated private extension LumenReplies {
    static let mocha = """
    A good café mocha balances three things: strong espresso, smooth chocolate, and creamy milk. Here is a simple way to make one at home.

    ---

    ## Classic Café Mocha

    ![Mocha](portrait.jpg)
    ![Latte art](landscape.jpg)

    ### Ingredients (1 serving)

    - 1 shot espresso (or 60 ml strong coffee)
    - 200 ml milk (dairy or plant-based)
    - 1–2 tbsp chocolate syrup or cocoa powder
    - 1 tsp sugar (optional)
    - Whipped cream (optional)

    ### Steps

    1. Stir the chocolate into the hot espresso until smooth.
    2. Heat the milk to about **60–65 °C** and froth it.
    3. Pour the milk over the chocolate espresso.
    4. Top with whipped cream and a little cocoa.

    Enjoy it while it's hot!
    """

    static let mochaShort = """
    Here is the quick version.

    1. Mix **2 tbsp cocoa** and a little sugar into a hot espresso.
    2. Add **200 ml** steamed milk.
    3. Finish with whipped cream if you like.

    ![Mocha](portrait.jpg)
    ![Latte art](landscape.jpg)
    """

    static let trip = """
    Here is an easy two-day plan that keeps travel time short.

    ## Day 1 — City and sea

    - **Morning:** walk the coastal path at Haeundae.
    - **Afternoon:** colorful houses at Gamcheon Culture Village.
    - **Evening:** grilled fish at Jagalchi Market.

    ## Day 2 — Slow morning

    - Coffee with a view at Yeongdo.
    - Taejongdae cliffs before heading home.

    > Tip: book the train back before noon on Sunday. Afternoon seats sell out.
    """

    static let tripShort = """
    Short on time? Pick **one area** and stay there:

    1. Haeundae for the beach.
    2. Nampo for markets and food.
    3. Yeongdo for cafés and cliffs.
    """

    static let interest = """
    Compound interest means you earn interest **on your interest**.

    Say you save **$100** at **10%** a year:

    1. After year 1 you have $110.
    2. In year 2 you earn 10% of $110, so you have $121.
    3. In year 3 you earn 10% of $121, so you have $133.10.

    The extra money grows faster every year. That is why starting early matters more than saving a lot later.
    """

    static let interestShort = """
    Think of a snowball rolling downhill. It picks up snow, and the bigger it gets, the more snow it picks up each turn. Money with compound interest grows the same way.
    """

    static let code = """
    Here is a small function that reverses the order of words:

    ```swift
    func reverseWords(_ sentence: String) -> String {
        sentence
            .split(separator: " ")
            .reversed()
            .joined(separator: " ")
    }
    ```

    For example, `reverseWords("hello big world")` returns `"world big hello"`.

    `split` drops repeated spaces, so the result always has single spaces.
    """

    static let codeShort = """
    A one-liner works too:

    ```swift
    let reversed = sentence.split(separator: " ").reversed().joined(separator: " ")
    ```
    """

    static let mainActor = """
    `@MainActor` on a class means **every property and method runs on the main thread**, unless you opt one out with `nonisolated`.

    - UI code can call it directly.
    - Calls from other actors need `await`.

    ```swift
    @MainActor
    final class Counter {
        var count = 0
        func increment() { count += 1 }
    }
    ```
    """

    static let mainActorShort = """
    In short: `@MainActor` pins the whole class to the main thread. It is the safe default for anything that touches the UI.
    """

    static let birthday = """
    Happy birthday, Sam! 🎉 Another year of great talks, bad jokes, and good food. Thanks for always being there. Let's celebrate this weekend!
    """

    static let photo = """
    Thanks for the photo. This demo can't look at images, but in a real app the answer would describe what's in it.
    """

    static let image = """
    Here is an image based on your idea:

    ![Generated image](landscape.jpg)

    Want me to change the colors or the style?
    """

    static let search = """
    Here is what I found from recent sources:

    - **Point one:** a short summary of the first result.
    - **Point two:** what a second source adds.

    ### Sources

    1. example.com — *Article title*
    2. example.org — *Another article*
    """
}
