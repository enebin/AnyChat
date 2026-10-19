import SwiftUI
import AnyChatUI

/// An agent transcript built from public API only: each step is a message carrying an
/// `AgentStep` as custom content, a typed row slot draws it, and the repository changes or removes
/// steps by id as the run goes on. The user's own prompts keep the default bubble.
struct AgentDemo: View {
    private static let channel = ChatChannel(
        id: "agent",
        name: "Agent",
        createdAt: Date(),
        members: [SampleData.me, SampleData.assistant]
    )

    @State private var repository = AgentChannelRepository()

    var body: some View {
        ChannelView(channel: Self.channel, repository: repository, currentUserID: SampleChatBackend.currentUserID)
            .messageRow(AgentStep.self) { step, message, _ in
                // Cells are reused, so the row's own state (a tool list left open) must follow
                // the message rather than the cell.
                AgentStepRow(step: step)
                    .id(message.id)
            }
    }
}

/// One step of an agent run, carried as a message's custom content.
nonisolated enum AgentStep: Hashable, Sendable {
    case status(startedAt: Date, finishedAt: Date?)
    case prose(String)
    case tools([ToolRun])
    case thinking

    /// The message text, for anything that draws the message without this type's renderer.
    var plainText: String {
        switch self {
        case .status(_, nil): "Working"
        case .status: "Done"
        case let .prose(text): text
        case let .tools(runs): ToolRun.summary(of: runs)
        case .thinking: "Thinking"
        }
    }
}

nonisolated struct ToolRun: Hashable, Sendable {
    enum Kind: CaseIterable {
        case read
        case search
        case command

        var symbol: String {
            switch self {
            case .read: "doc.text"
            case .search: "magnifyingglass"
            case .command: "terminal"
            }
        }

        func summary(count: Int) -> String {
            switch self {
            case .read: count == 1 ? "Read 1 file" : "Read \(count) files"
            case .search: count == 1 ? "Searched once" : "Searched \(count) times"
            case .command: count == 1 ? "Ran 1 command" : "Ran \(count) commands"
            }
        }
    }

    let kind: Kind
    let target: String

    static func summary(of runs: [ToolRun]) -> String {
        Kind.allCases
            .compactMap { kind in
                let count = runs.filter { $0.kind == kind }.count
                return count > 0 ? kind.summary(count: count) : nil
            }
            .joined(separator: " · ")
    }
}

private struct AgentStepRow: View {
    let step: AgentStep

    var body: some View {
        Group {
            switch step {
            case let .status(startedAt, finishedAt):
                StatusLine(startedAt: startedAt, finishedAt: finishedAt)
            case let .prose(text):
                Prose(text: text)
            case let .tools(runs):
                ToolRunList(runs: runs)
            case .thinking:
                ThinkingLabel()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct StatusLine: View {
    let startedAt: Date
    let finishedAt: Date?

    @Environment(\.channelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(text(now: context.date))
            }
            Divider()
        }
        .font(theme.systemMessageFont)
        .foregroundStyle(theme.systemMessageText)
    }

    private func text(now: Date) -> String {
        let end = finishedAt ?? now
        let elapsed = Duration.seconds(max(0, end.timeIntervalSince(startedAt).rounded(.down)))
        let formatted = elapsed.formatted(.units(allowed: [.minutes, .seconds], width: .wide))
        return finishedAt == nil ? "Working for \(formatted)" : "Worked for \(formatted)"
    }
}

private struct Prose: View {
    let text: String

    @Environment(\.channelTheme) private var theme

    var body: some View {
        Text(attributedText)
            .font(theme.messageFont)
            .foregroundStyle(theme.incomingMessageText)
    }

    /// Markdown, with inline code set on a tinted background like a chip.
    private var attributedText: AttributedString {
        var attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        let codeRanges = attributed.runs
            .filter { $0.inlinePresentationIntent?.contains(.code) == true }
            .map(\.range)
        for range in codeRanges {
            attributed[range].backgroundColor = theme.dateSeparatorBackground
        }
        return attributed
    }
}

private struct ToolRunList: View {
    let runs: [ToolRun]

    @State private var isExpanded = false
    @Environment(\.channelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    ForEach(ToolRun.Kind.allCases.filter { kind in runs.contains { $0.kind == kind } }, id: \.self) { kind in
                        Image(systemName: kind.symbol)
                    }
                    Text(ToolRun.summary(of: runs))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(runs, id: \.self) { run in
                    Label(run.target, systemImage: run.kind.symbol)
                        .font(.caption.monospaced())
                        .padding(.leading, 4)
                }
            }
        }
        .font(theme.systemMessageFont)
        .foregroundStyle(theme.systemMessageText)
    }
}

private struct ThinkingLabel: View {
    @State private var isDimmed = false
    @Environment(\.channelTheme) private var theme

    var body: some View {
        Text("Thinking")
            .font(theme.systemMessageFont)
            .foregroundStyle(theme.systemMessageText)
            .opacity(isDimmed ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(), value: isDimmed)
            .onAppear { isDimmed = true }
    }
}
