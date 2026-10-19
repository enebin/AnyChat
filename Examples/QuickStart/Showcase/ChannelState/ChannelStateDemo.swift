import SwiftUI
import AnyChatUI

/// Passes newer values of the open channel to the same `ChannelView`. The screen does not observe
/// the channel itself, so the host hands it each change.
struct ChannelStateDemo: View {
    @State private var backend = SampleChatBackend()
    @State private var selectedChannel: ChatChannel?

    var body: some View {
        ChannelListView()
            .onChannelSelected { selectedChannel = $0 }
            .navigationTitleText("Channel state")
            // A pushed view takes its environment from the stack, which sits above this demo.
            .navigationDestination(item: $selectedChannel) { channel in
                FreezableChannelScreen(initialChannel: channel)
                    .chatBackend(backend)
            }
            .chatBackend(backend)
    }
}

private struct FreezableChannelScreen: View {
    let initialChannel: ChatChannel

    @State private var channel: ChatChannel

    init(initialChannel: ChatChannel) {
        self.initialChannel = initialChannel
        _channel = State(initialValue: initialChannel)
    }

    var body: some View {
        ChannelView(channel: channel)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(channel.isFrozen ? "Unfreeze" : "Freeze") {
                        channel.isFrozen.toggle()
                        // A broadcast channel stays read-only after unfreezing; a channel that
                        // opened frozen can send once unfrozen.
                        channel.canSendMessage = !channel.isFrozen
                            && (initialChannel.canSendMessage || initialChannel.isFrozen)
                    }
                }
            }
    }
}
