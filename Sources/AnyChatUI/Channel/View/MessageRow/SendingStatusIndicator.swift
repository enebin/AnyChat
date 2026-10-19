import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// Takes the place of the receipt and time while a message is unsent: a turning spinner while it
/// sends, an error icon once it failed.
struct SendingStatusIndicator: View {
    let status: ChatMessage.SendingStatus
    let size: CGFloat

    @Environment(\.channelTheme) private var theme

    private let secondsPerTurn: Double = 1

    var body: some View {
        switch status {
        case .pending:
            TimelineView(.animation) { context in
                ChatIcon.spinner.sized(size)
                    .foregroundStyle(theme.sendingIndicatorTint)
                    .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate / secondsPerTurn * 360))
            }
            .frame(width: size, height: size)
            .accessibilityLabel("Sending")
        case .failed:
            ChatIcon.error.sized(size)
                .foregroundStyle(theme.failedIndicatorTint)
                .accessibilityLabel("Failed to send")
        }
    }
}
