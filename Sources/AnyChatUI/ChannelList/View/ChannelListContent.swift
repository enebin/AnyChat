import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// The channel list screen itself. `ChannelListView` decides which repository it gets.
///
/// Owns the store through `@State`, so a parent redraw that rebuilds this view keeps the list.
struct ChannelListContent: View {
    @State private var store: ChannelListStore

    let slots: ChannelListSlots
    let callbacks: ChannelListCallbacks
    let title: String

    @Environment(\.channelListTheme) private var theme

    /// How many rows from the end the next page starts loading.
    private let preloadDistance = 10

    /// The design source draws the swipe action icons at 24pt.
    private let swipeIconSize: CGFloat = 24

    init(
        repository: any ChannelListRepository,
        currentUserID: String?,
        options: ChannelListOptions,
        slots: ChannelListSlots = ChannelListSlots(),
        callbacks: ChannelListCallbacks = ChannelListCallbacks(),
        title: String = ChannelListView.defaultTitle
    ) {
        _store = State(
            initialValue: ChannelListStore(
                repository: repository,
                currentUserID: currentUserID,
                options: options
            )
        )
        self.slots = slots
        self.callbacks = callbacks
        self.title = title
    }

    var body: some View {
        List {
            listHeader

            ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(theme.background)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in ChannelRow.separatorLeading }
                    .listRowSeparatorTint(theme.separator)
                    .onAppear { loadNextPageIfNeeded(at: index) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) { swipeActions(for: row) }
            }

            PaginationFooter(status: store.state.paginationStatus) {
                store.send(.retryNextPage)
            }
            .listRowBackground(theme.background)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .refreshable {
            await store.refresh()
        }
        .overlay { screenState }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                createChannelButton
            }
        }
        .task { store.send(.start) }
        .onChange(of: store.outboundEvent?.id) { _, _ in
            dispatchOutboundEvent()
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: ChannelRowState) -> some View {
        let channel = store.state.channel(for: row.id)

        Button {
            if let channel {
                callbacks.channelSelected?(channel)
            }
        } label: {
            Group {
                if let slot = slots.row, let channel {
                    slot(channel)
                } else {
                    ChannelRow(row: row, channel: channel, slots: slots)
                }
            }
            // A plain button only hit-tests what its label draws, so the gaps between texts would not open the channel.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Outside the `ForEach`, so the row indices that start the next page are unchanged.
    @ViewBuilder
    private var listHeader: some View {
        if let header = slots.listHeader {
            header()
                // Buttons in a list row otherwise take the whole row's taps, so a tap on blank
                // space would fire them.
                .buttonStyle(.borderless)
                .listRowInsets(EdgeInsets())
                .listRowBackground(theme.background)
                .listRowSeparator(.hidden)
        }
    }

    /// SwiftUI always draws swipe action labels in white, so only the background is themeable.
    /// Every action background has to stay dark enough for white content to read.
    ///
    /// It also ignores `resizable`, `frame` and `fixedSize` on the label's icon, so the icons
    /// here go through `redrawn(at:)` instead.
    @ViewBuilder
    private func swipeActions(for row: ChannelRowState) -> some View {
        if row.canLeave {
            Button(role: .destructive) {
                store.send(.leave(channelID: row.id))
            } label: {
                Label {
                    Text("Leave")
                } icon: {
                    ChatIcon.leave.redrawn(at: swipeIconSize)
                }
            }
            .tint(theme.leaveActionBackground)
            .disabled(row.isActionPending)
        }

        if row.canToggleNotifications {
            Button {
                store.send(.toggleNotifications(channelID: row.id))
            } label: {
                Label {
                    Text(row.isNotificationOff ? "Notifications on" : "Notifications off")
                } icon: {
                    (row.isNotificationOff ? ChatIcon.notificationFilled : ChatIcon.notificationOffFilled)
                        .redrawn(at: swipeIconSize)
                }
            }
            .tint(row.isNotificationOff ? theme.notificationOnActionBackground : theme.notificationOffActionBackground)
            .disabled(row.isActionPending)
        }
    }

    // MARK: - Screen state

    @ViewBuilder
    private var screenState: some View {
        switch store.state.phase {
        case .loading:
            ProgressView()

        case .empty:
            Placeholder(
                icon: .chat,
                text: "No channels",
                tint: theme.placeholderTint,
                font: theme.messageFont
            )

        case let .error(message):
            Placeholder(
                icon: .error,
                text: message,
                tint: theme.placeholderTint,
                font: theme.messageFont,
                retry: .init(title: "Retry", tint: theme.barButtonTint) { store.send(.retry) }
            )

        case .idle, .loaded:
            EmptyView()
        }
    }

    @ViewBuilder
    private var createChannelButton: some View {
        if let slot = slots.createChannelButton {
            Button {
                callbacks.createChannelTapped?()
            } label: {
                slot()
            }
            .tint(theme.barButtonTint)
        } else {
            IconButton(.create, tint: theme.barButtonTint) {
                callbacks.createChannelTapped?()
            }
        }
    }

    // MARK: - Actions

    private func loadNextPageIfNeeded(at index: Int) {
        let count = store.rows.count
        guard index >= count - preloadDistance else {
            return
        }
        store.send(.loadNextPage)
    }

    private func dispatchOutboundEvent() {
        guard let event = store.outboundEvent?.event else {
            return
        }

        switch event {
        case let .leftChannel(channel):
            callbacks.leftChannel?(channel)
        case let .notificationLevelChanged(channel):
            callbacks.notificationLevelChanged?(channel)
        case let .failed(message):
            callbacks.failed?(ChannelListError(message: message))
        }
    }
}

#if DEBUG
/// Feeds the preview a fixed list without touching a backend.
@MainActor
private final class PreviewRepository: ChannelListRepository {
    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    func startObserving() -> AsyncStream<[ChatChannel]> {
        AsyncStream { $0.finish() }
    }

    func loadMore() async throws -> ChannelListPage {
        ChannelListPage(channels: [], hasNext: false)
    }

    func leave(channelID: String) async throws {}
    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {}
    func stopObserving() {}
}

#Preview("Empty state") {
    NavigationStack {
        ChannelListView(repository: PreviewRepository(), currentUserID: "me")
    }
}
#endif
