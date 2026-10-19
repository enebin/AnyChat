import Observation
import AnyChatCore
import SwiftUI

@Observable
final class MessageListCellPresentation {
    var slots = ChannelSlots()
    var environment = EnvironmentValues()
    var onRetry: () -> Void = {}
    var onFailedMessageSelected: (ChatMessage) -> Void = { _ in }
    var signals = MessageSignals()
    /// The message whose bubble the long-press overlay draws in its place, so its cell hides it.
    var liftedMessageID: String?
    /// Reports a bubble's frame in its cell's coordinate space, or `nil` when it has nothing to
    /// open. Cells report; nothing observes it.
    @ObservationIgnored var onBubbleFrameChange: (String, CGRect?) -> Void = { _, _ in }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}
}
