import SwiftUI
import AnyChatUI

/// One chat on screen, with the drawer of past chats sliding in from the left. A new chat is an empty
/// one, which offers suggestions until its first message.
struct RootScreen: View {
    let backend: LumenBackend

    @State private var selectedChannelID: String
    @State private var isDrawerOpen = false
    @State private var isShowingSplash = true

    private let drawerWidth: CGFloat = 318

    init(backend: LumenBackend) {
        self.backend = backend
        _selectedChannelID = State(initialValue: backend.newChat().id)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                main
            }
            .offset(x: isDrawerOpen ? drawerWidth : 0)
            .overlay {
                if isDrawerOpen {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .offset(x: drawerWidth)
                        .onTapGesture { setDrawer(open: false) }
                        .gesture(DragGesture().onEnded { if $0.translation.width < -40 { setDrawer(open: false) } })
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Close chats")
                }
            }

            ChatDrawer(
                selectedChannelID: selectedChannelID,
                onNewChat: { open(backend.newChat().id) },
                onSelect: { open($0.id) }
            )
            .frame(width: drawerWidth)
            .offset(x: isDrawerOpen ? 0 : -drawerWidth)
            .accessibilityHidden(!isDrawerOpen)
        }
        .overlay {
            if isShowingSplash {
                SplashView().transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.25)) { isShowingSplash = false }
        }
    }

    @ViewBuilder
    private var main: some View {
        if let channel = backend.channel(id: selectedChannelID) {
            ChatScreen(
                channel: channel,
                backend: backend,
                onOpenDrawer: { setDrawer(open: true) },
                onNewChat: { open(backend.newChat().id) },
                onDelete: {
                    try? backend.delete(channelID: channel.id)
                    open(backend.newChat().id)
                }
            )
        }
    }

    private func open(_ channelID: String) {
        selectedChannelID = channelID
        setDrawer(open: false)
    }

    private func setDrawer(open: Bool) {
        if open {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        withAnimation(.snappy(duration: 0.3)) { isDrawerOpen = open }
    }
}

private struct SplashView: View {
    var body: some View {
        LumenStyle.background
            .ignoresSafeArea()
            .overlay {
                LumenMark()
                    .stroke(LumenStyle.secondaryInk.opacity(0.6), lineWidth: 1.3)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Lumen")
    }
}
