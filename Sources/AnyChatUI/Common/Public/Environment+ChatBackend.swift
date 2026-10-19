import SwiftUI

public extension EnvironmentValues {
    /// The backend screens in this part of the view tree load from. `nil` until one is registered.
    ///
    /// - Since: 1.0.0
    @Entry var chatBackend: (any ChatBackend)? = nil
}

public extension View {
    /// Registers the backend that screens below this view load from. Call it once near the root.
    ///
    /// - Since: 1.0.0
    func chatBackend(_ backend: any ChatBackend) -> some View {
        environment(\.chatBackend, backend)
    }
}
