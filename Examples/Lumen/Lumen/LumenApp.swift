import SwiftUI
import AnyChatUI

@main
struct LumenApp: App {
    @State private var backend = LumenBackend()

    var body: some Scene {
        WindowGroup {
            RootScreen(backend: backend)
                .chatBackend(backend)
                .channelTheme(LumenStyle.channelTheme)
                .channelListTheme(LumenStyle.channelListTheme)
                .tint(LumenStyle.ink)
        }
    }
}
