import XCTest
@testable import Lumen

final class MarkdownBlockTests: XCTestCase {
    func testParsesHeadingsListsRulesAndParagraphs() {
        // Given
        let markdown = """
        Intro line one
        continues here.

        ---

        ## Title

        - first
        - second

        1. one
        2. two
        """

        // When
        let blocks = MarkdownBlock.parse(markdown)

        // Then
        XCTAssertEqual(blocks, [
            .paragraph("Intro line one continues here."),
            .rule,
            .heading(level: 2, text: "Title"),
            .bulletList(["first", "second"]),
            .numberedList([.init(number: 1, text: "one"), .init(number: 2, text: "two")]),
        ])
    }

    func testGroupsConsecutiveImagesIntoOneStrip() {
        // Given
        let markdown = "![A](a.jpg)\n![B](b.jpg)\nAfter"

        // When
        let blocks = MarkdownBlock.parse(markdown)

        // Then
        XCTAssertEqual(blocks, [.images(["a.jpg", "b.jpg"]), .paragraph("After")])
    }

    func testKeepsCodeIndentationAndIgnoresMarkdownInsideFence() {
        // Given
        let markdown = "```swift\nfunc a() {\n    # not a heading\n}\n```"

        // When
        let blocks = MarkdownBlock.parse(markdown)

        // Then
        XCTAssertEqual(blocks, [.code(language: "swift", text: "func a() {\n    # not a heading\n}")])
    }

    func testTreatsUnclosedFenceAsGrowingCodeBlock() {
        // Given
        let streamed = "Here:\n\n```swift\nlet x = 1"

        // When
        let blocks = MarkdownBlock.parse(streamed)

        // Then
        XCTAssertEqual(blocks, [.paragraph("Here:"), .code(language: "swift", text: "let x = 1")])
    }

    func testDoesNotTreatHashWithoutSpaceAsHeading() {
        // Given
        let markdown = "#hashtag"

        // When
        let blocks = MarkdownBlock.parse(markdown)

        // Then
        XCTAssertEqual(blocks, [.paragraph("#hashtag")])
    }
}

final class ReplyWordsTests: XCTestCase {
    func testWordsKeepTrailingWhitespaceSoTheyJoinBackToTheText() {
        // Given
        let text = "Hello  big\nworld "

        // When
        let words = LumenReplies.words(of: text)

        // Then
        XCTAssertEqual(words, ["Hello  ", "big\n", "world "])
        XCTAssertEqual(words.joined(), text)
    }
}
