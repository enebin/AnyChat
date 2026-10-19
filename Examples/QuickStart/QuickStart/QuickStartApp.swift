import SwiftUI
import AnyChatUI

@main
struct QuickStartApp: App {
    @State private var backend = SampleChatBackend()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChannelListScreen(replies: backend.replies)
            }
            .chatBackend(backend)
        }
    }
}
