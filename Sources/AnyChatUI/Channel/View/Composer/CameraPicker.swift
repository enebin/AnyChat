import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI has no camera capture view, so this wraps `UIImagePickerController`.
struct CameraPicker: UIViewControllerRepresentable {
    let allowsVideo: Bool
    let onPick: (AttachmentSource) -> Void
    let onDismiss: () -> Void

    /// The system ends an app that opens the camera without these Info.plist keys, so the menu
    /// offers the camera only when the host app declares them.
    static var canTakePhotos: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera) && hasUsageDescription("NSCameraUsageDescription")
    }

    static var canRecordVideos: Bool {
        canTakePhotos
            && hasUsageDescription("NSMicrophoneUsageDescription")
            && (UIImagePickerController.availableMediaTypes(for: .camera) ?? []).contains(UTType.movie.identifier)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = allowsVideo ? [UTType.image.identifier, UTType.movie.identifier] : [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onDismiss: onDismiss)
    }

    private static func hasUsageDescription(_ key: String) -> Bool {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.isEmpty == false
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (AttachmentSource) -> Void
        private let onDismiss: () -> Void

        init(onPick: @escaping (AttachmentSource) -> Void, onDismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.onDismiss = onDismiss
        }

        // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
        nonisolated deinit {}

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                onPick(.cameraVideo(url))
            } else if let image = info[.originalImage] as? UIImage {
                onPick(.cameraPhoto(image))
            }
            onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}
