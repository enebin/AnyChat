import Foundation

/// Turns a backend error into text a screen can show.
nonisolated enum ErrorMessage {
    static let generic = "Something went wrong. Please try again."

    /// Only errors that describe themselves for display are shown as-is; anything else would
    /// surface a developer-facing description.
    static func text(for error: any Error) -> String {
        guard let description = (error as? LocalizedError)?.errorDescription, !description.isEmpty else {
            return generic
        }
        return description
    }
}
