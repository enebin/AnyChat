import SwiftUI
import AnyChatUI

@main
struct PrismApp: App {
    @State private var backend = PrismBackend()

    var body: some Scene {
        WindowGroup {
            InboxScreen(backend: backend)
                .chatBackend(backend)
                .channelListTheme(PrismStyle.channelListTheme)
                .channelTheme(PrismStyle.channelTheme)
        }
    }
}
