import SwiftUI
import AnyChatUI

/// A capsule with a camera button at the front. Photo and attach buttons sit at the end until there
/// is text, when a Send button takes their place.
struct ThreadComposer: View {
    let context: ComposerContext

    @State private var draft = ""

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                if context.canOpenCamera {
                    context.openCamera()
                } else {
                    context.openPhotoLibrary()
                }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(PrismStyle.accent))
            }
            .accessibilityLabel(context.canOpenCamera ? "Camera" : "Photo library")

            TextField(placeholder, text: $draft, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(.vertical, 8)

            if hasDraft {
                Button("Send") {
                    guard context.canSend else { return }
                    context.send(text: draft)
                    draft = ""
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PrismStyle.accent)
                .frame(height: 36)
            } else {
                Group {
                    Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
                        .accessibilityLabel("Photo library")
                    Button { context.openAttachmentMenu() } label: { Image(systemName: "plus.circle") }
                        .accessibilityLabel("Attach")
                }
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.primary)
                .frame(height: 36)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 14)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .disabled(!context.canSend)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var placeholder: String {
        context.isUnavailable ? "Chat is unavailable" : "Message..."
    }
}
