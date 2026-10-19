import SwiftUI

/// Lists the customization demos. Each demo registers its own `SampleChatBackend`, or hands its own
/// repository to the screen, so a change in one demo (leaving a channel, for example) does not show
/// up in another.
@main
struct ShowcaseApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Themes") { ThemeDemo() }
                    NavigationLink("Slots") { SlotDemo() }
                    NavigationLink("Composer") { ComposerDemo() }
                    NavigationLink("Reactions") { ReactionsDemo() }
                    NavigationLink("Streaming") { StreamingDemo() }
                    NavigationLink("Channel state") { ChannelStateDemo() }
                    NavigationLink("Agent") { AgentDemo() }
                }
                .navigationTitle("Showcase")
            }
        }
    }
}
