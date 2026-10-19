import SwiftUI
import AnyChatUI

// Register a backend with `.chatBackend(_:)` on a view above this one, usually the app's root view.
struct ChatHomeScreen: View {
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        NavigationStack {
            ChannelListView()
                .onChannelSelected { channel in
                    selectedChannel = channel
                }
                .navigationDestination(item: $selectedChannel) { channel in
                    ChannelView(channel: channel)
                }
        }
    }
}
