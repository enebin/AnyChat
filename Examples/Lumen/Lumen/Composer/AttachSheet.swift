import SwiftUI
import AnyChatUI

struct AttachSheet: View {
    enum Choice {
        case picker(() -> Void)
        case tool(ToolMode)
    }

    let context: ComposerContext
    let onChoose: (Choice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if context.canOpenCamera {
                    tile("camera", title: "Camera") { onChoose(.picker(context.openCamera)) }
                }
                tile("photo", title: "Photos") { onChoose(.picker(context.openPhotoLibrary)) }
                tile("paperclip", title: "Files") { onChoose(.picker(context.openFiles)) }
            }
            Rectangle()
                .fill(Color(light: 0xDCDCDC, dark: 0x333333))
                .frame(height: 1)
                .padding(.top, 24)
                .padding(.bottom, 8)
            ForEach(ToolMode.allCases, id: \.self) { mode in
                Button {
                    onChoose(.tool(mode))
                } label: {
                    HStack(spacing: 18) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 20))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(mode.title).font(.system(size: 17))
                            Text(mode.subtitle).font(.system(size: 15)).foregroundStyle(LumenStyle.secondaryInk)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(LumenStyle.ink)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(40)
        .presentationBackground(LumenStyle.sheetBackground)
    }

    private func tile(_ systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 20))
                Text(title).font(.system(size: 17))
            }
            .foregroundStyle(LumenStyle.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LumenStyle.tile))
        }
        .buttonStyle(.plain)
    }
}
