import Foundation

/// One block of an answer. Inline styling (bold, code, links) stays in the text for `AttributedString`.
nonisolated enum MarkdownBlock: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([NumberedItem])
    case code(language: String?, text: String)
    case quote(String)
    case rule
    /// Consecutive `![alt](file)` lines, shown side by side.
    case images([String])

    struct NumberedItem: Hashable, Sendable {
        var number: Int
        var text: String
    }

    /// Parses a streaming answer too: an unclosed code fence is a code block that is still growing.
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [NumberedItem] = []
        var images: [String] = []
        var quote: [String] = []
        var code: (language: String?, lines: [String])?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            if !bullets.isEmpty { blocks.append(.bulletList(bullets)) }
            if !numbered.isEmpty { blocks.append(.numberedList(numbered)) }
            if !images.isEmpty { blocks.append(.images(images)) }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: " "))) }
            paragraph = []
            bullets = []
            numbered = []
            images = []
            quote = []
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let open = code {
                if line.hasPrefix("```") {
                    blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n")))
                    code = nil
                } else {
                    code?.lines.append(rawLine)
                }
                continue
            }

            if line.hasPrefix("```") {
                flush()
                let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                code = (language.isEmpty ? nil : language, [])
            } else if line.isEmpty {
                flush()
            } else if line == "---" || line == "***" {
                flush()
                blocks.append(.rule)
            } else if let heading = heading(in: line) {
                flush()
                blocks.append(heading)
            } else if let file = imageFile(in: line) {
                if images.isEmpty { flush() }
                images.append(file)
            } else if let item = bullet(in: line) {
                if bullets.isEmpty { flush() }
                bullets.append(item)
            } else if let item = numberedItem(in: line) {
                if numbered.isEmpty { flush() }
                numbered.append(item)
            } else if line.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
            } else {
                if paragraph.isEmpty { flush() }
                paragraph.append(line)
            }
        }

        flush()
        if let open = code {
            blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n")))
        }
        return blocks
    }

    private static func heading(in line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else {
            return nil
        }
        return .heading(level: hashes, text: line.dropFirst(hashes + 1).trimmingCharacters(in: .whitespaces))
    }

    private static func bullet(in line: String) -> String? {
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func numberedItem(in line: String) -> NumberedItem? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits), line.dropFirst(digits.count).hasPrefix(". ") else {
            return nil
        }
        return NumberedItem(number: number, text: String(line.dropFirst(digits.count + 2)))
    }

    private static func imageFile(in line: String) -> String? {
        guard line.hasPrefix("!["), line.hasSuffix(")"), let open = line.range(of: "](") else {
            return nil
        }
        return String(line[open.upperBound..<line.index(before: line.endIndex)])
    }
}
