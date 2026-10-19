import OSLog
import AnyChatDesignSystem
import SwiftUI

/// What a screen shows when no backend is registered.
///
/// Never crashes: a missing registration shows a placeholder and logs a fault instead.
struct MissingBackendView: View {
    /// The public screen type, named in the developer hint and the log.
    let screenName: String
    let tint: Color
    let font: Font
    let background: Color

    var body: some View {
        VStack(spacing: 16) {
            Placeholder(icon: .error, text: "Chat is unavailable", tint: tint, font: font)
            #if DEBUG
            Text("No chat backend is registered. Call chatBackend(_:) on a view above \(screenName).")
                .font(font)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .onAppear {
            Self.logger.fault(
                "\(screenName, privacy: .public) appeared without a chat backend. Register one with chatBackend(_:)."
            )
        }
    }

    private static let logger = Logger(subsystem: "AnyChatUI", category: "Backend")
}
