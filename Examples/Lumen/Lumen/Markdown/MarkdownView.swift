import SwiftUI
import AnyChatUI

/// Draws an answer's Markdown. Images named in the text come from the message's attachments.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]
    let attachments: [ChatAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            InlineText(text)
                .font(.system(size: level == 1 ? 24 : level == 2 ? 21 : 17, weight: level <= 2 ? .bold : .semibold))
                .padding(.top, 4)
        case let .paragraph(text):
            InlineText(text).font(LumenStyle.bodyFont).lineSpacing(LumenStyle.bodyLineSpacing)
        case let .bulletList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ListItem(marker: "•", text: item)
                }
            }
        case let .numberedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ListItem(marker: "\(item.number).", text: item.text)
                }
            }
        case let .code(language, text):
            CodeBlock(language: language, text: text)
        case let .quote(text):
            InlineText(text)
                .font(LumenStyle.bodyFont)
                .foregroundStyle(LumenStyle.secondaryInk)
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Capsule().fill(LumenStyle.divider).frame(width: 3)
                }
        case .rule:
            Rectangle().fill(LumenStyle.divider).frame(height: 1).padding(.vertical, 8)
        case let .images(files):
            ImageStrip(urls: files.compactMap { file in attachments.first { $0.fileName == file }?.url })
        }
    }
}

private struct InlineText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        Text(attributed)
            .foregroundStyle(LumenStyle.ink)
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private struct ListItem: View {
    let marker: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker)
                .font(LumenStyle.bodyFont)
                .foregroundStyle(LumenStyle.ink)
                .frame(minWidth: 14, alignment: .leading)
            InlineText(text).font(LumenStyle.bodyFont).lineSpacing(LumenStyle.bodyLineSpacing)
        }
        .padding(.leading, 6)
    }
}

private struct CodeBlock: View {
    let language: String?
    let text: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LumenStyle.secondaryInk)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(LumenStyle.secondaryInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(LumenStyle.ink)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LumenStyle.codeBackground))
    }
}

/// Images in a row that scrolls sideways, as tall as the design's recipe photos.
private struct ImageStrip: View {
    let urls: [URL]

    private let height: CGFloat = 141

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(urls, id: \.self) { url in
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: height * min(max(image.size.width / image.size.height, 0.75), 1.6), height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LumenStyle.card)
                            .frame(width: height * 0.8, height: height)
                    }
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityLabel("\(urls.count) images")
    }
}
