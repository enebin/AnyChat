import SwiftUI
import AnyChatUI

/// An assistant answer: no bubble, the full width of the screen, with actions once it is finished.
struct AnswerRow: View {
    let answer: Answer
    let message: ChatMessage
    let onFeedback: (Feedback?) -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if answer.phase == .thinking {
                ThinkingIndicator(label: answer.mode == .thinkLonger ? "Thinking" : nil)
            } else {
                MarkdownView(blocks: MarkdownBlock.parse(message.plainText), attachments: message.attachments)
                if answer.phase == .streaming {
                    PulsingDot()
                } else {
                    AnswerActions(
                        text: message.plainText,
                        feedback: message.attributes[Feedback.self],
                        wasStopped: answer.phase == .stopped,
                        onFeedback: onFeedback,
                        onRegenerate: onRegenerate
                    )
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnswerActions: View {
    let text: String
    let feedback: Feedback?
    let wasStopped: Bool
    let onFeedback: (Feedback?) -> Void
    let onRegenerate: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if wasStopped {
                Text("Stopped")
                    .font(.system(size: 13))
                    .foregroundStyle(LumenStyle.secondaryInk)
            }
            HStack(spacing: 4) {
                action(copied ? "checkmark" : "doc.on.doc", label: "Copy") {
                    UIPasteboard.general.string = text
                    copied = true
                }
                action(feedback == .good ? "hand.thumbsup.fill" : "hand.thumbsup", label: "Good response") {
                    onFeedback(feedback == .good ? nil : .good)
                }
                action(feedback == .bad ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "Bad response") {
                    onFeedback(feedback == .bad ? nil : .bad)
                }
                action("arrow.clockwise", label: "Regenerate", perform: onRegenerate)
            }
            .padding(.leading, -10)
        }
    }

    private func action(_ systemImage: String, label: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(LumenStyle.secondaryInk)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ThinkingIndicator: View {
    let label: String?

    var body: some View {
        HStack(spacing: 10) {
            PulsingDot()
            if let label {
                Text(label)
                    .font(LumenStyle.bodyFont)
                    .foregroundStyle(LumenStyle.secondaryInk)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }
}

struct PulsingDot: View {
    @State private var isLarge = false

    var body: some View {
        Circle()
            .fill(LumenStyle.ink)
            .frame(width: 12, height: 12)
            .scaleEffect(isLarge ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isLarge)
            .onAppear { isLarge = true }
            .accessibilityHidden(true)
    }
}
