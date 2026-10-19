import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The design source's attachment menu and the three pickers it opens. Whatever one pick returns
/// is handed over as one message. The flags are bindings, so a host's composer items can open a
/// picker directly.
struct AttachmentPickers: ViewModifier {
    @Binding var isShowingMenu: Bool
    @Binding var isShowingCamera: Bool
    @Binding var isShowingPhotoLibrary: Bool
    @Binding var isShowingFiles: Bool
    let onPick: ([AttachmentSource]) -> Void
    let onFailure: () -> Void

    @State private var photoLibraryItems: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Attach", isPresented: $isShowingMenu, titleVisibility: .hidden) {
                if CameraPicker.canTakePhotos {
                    Button("Camera") { isShowingCamera = true }
                }
                Button("Photo library") { isShowingPhotoLibrary = true }
                Button("Files") { isShowingFiles = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $isShowingPhotoLibrary,
                selection: $photoLibraryItems,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: photoLibraryItems) { _, items in
                guard !items.isEmpty else {
                    return
                }
                onPick(items.map(AttachmentSource.photoLibrary))
                photoLibraryItems = []
            }
            .fileImporter(isPresented: $isShowingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                // A cancel arrives through a separate callback, so only a pick or a failure reaches here.
                switch result {
                case let .success(urls):
                    if !urls.isEmpty {
                        onPick(urls.map(AttachmentSource.file))
                    }
                case .failure:
                    onFailure()
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker(
                    allowsVideo: CameraPicker.canRecordVideos,
                    onPick: { onPick([$0]) },
                    onDismiss: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
    }
}
