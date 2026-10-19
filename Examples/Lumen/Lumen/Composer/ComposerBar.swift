import SwiftUI
import AnyChatUI

/// The floating capsule: +, the field, a mic, and one round button that sends, stops, or starts voice.
struct ComposerBar: View {
    let context: ComposerContext
    let isGenerating: Bool
    @Binding var mode: ToolMode?
    let onStop: () -> Void

    @State private var draft = ""
    @State private var isAttaching = false
    @State private var pendingPicker: (() -> Void)?
    @State private var isShowingVoiceNotice = false

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let mode {
                ModeChip(mode: mode) { self.mode = nil }
                    .padding(.leading, 16)
            }
            HStack(alignment: .bottom, spacing: 10) {
                iconButton("plus", label: "Add", tint: LumenStyle.ink) { isAttaching = true }
                    .disabled(!context.canSend)

                TextField("Ask Lumen", text: $draft, axis: .vertical)
                    .font(LumenStyle.bodyFont)
                    .foregroundStyle(LumenStyle.ink)
                    .lineLimit(1...6)
                    .padding(.vertical, 13)

                if !hasDraft {
                    iconButton("mic", label: "Dictate", tint: LumenStyle.secondaryInk) { isShowingVoiceNotice = true }
                }
                roundButton
                    .padding(.bottom, 7)
            }
            .padding(.leading, 10)
            .padding(.trailing, 7)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LumenStyle.background)
                    .shadow(color: .black.opacity(0.09), radius: 11, y: 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .sheet(isPresented: $isAttaching, onDismiss: runPendingPicker) {
            AttachSheet(context: context) { choice in
                switch choice {
                case .picker(let open): pendingPicker = open
                case .tool(let tool): mode = tool
                }
                isAttaching = false
            }
        }
        .alert("Voice isn't part of this demo", isPresented: $isShowingVoiceNotice) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var roundButton: some View {
        if hasDraft {
            round("arrow.up", label: "Send") {
                guard context.canSend, !isGenerating else { return }
                context.send(text: draft)
                draft = ""
            }
            .opacity(isGenerating ? 0.3 : 1)
        } else if isGenerating {
            round("stop.fill", label: "Stop generating", size: 12, action: onStop)
        } else {
            round("waveform", label: "Voice mode") { isShowingVoiceNotice = true }
        }
    }

    private func round(_ systemImage: String, label: String, size: CGFloat = 15, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(LumenStyle.actionGlyph)
                .frame(width: 34, height: 34)
                .background(Circle().fill(LumenStyle.actionFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func iconButton(_ systemImage: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 32, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// A picker can only appear once the sheet has gone.
    private func runPendingPicker() {
        pendingPicker?()
        pendingPicker = nil
    }
}

private struct ModeChip: View {
    let mode: ToolMode
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                Text(mode.title)
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(LumenStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(LumenStyle.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.title), remove")
    }
}
