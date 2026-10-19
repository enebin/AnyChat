import PhotosUI
import SwiftUI
import UIKit

/// What a picker returned, before it is copied into a file the adapter can upload.
///
/// It travels in Reducer inputs and keys the Store's preparation slot, so every case is `Hashable`
/// and `Sendable`.
nonisolated enum AttachmentSource: Hashable, Sendable {
    case photoLibrary(PhotosPickerItem)
    /// A URL from the file importer. It is security-scoped and readable only while copying.
    case file(URL)
    case cameraPhoto(UIImage)
    /// A movie the camera wrote to its own temporary file.
    case cameraVideo(URL)
}
