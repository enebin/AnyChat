import OSLog
import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// The channel screen itself. `ChannelView` decides which repository it gets.
///
/// Owns the store through `@State`, so a parent redraw that rebuilds this view keeps the list.
struct ChannelContent: View {
    @State private var store: ChannelStore

    let channel: ChatChannel
    let currentUserID: String?
    let slots: ChannelSlots

    @Environment(\.channelTheme) private var theme
    @State private var bannerHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var isHeaderSlotEmpty = false
    @State private var selectedFailedMessage: ChatMessage?
    /// The long-pressed message whose overlay is open. Presentation state, outside the Store, like
    /// the failed-message dialog.
    @State private var overlayMessageID: String?
    /// The lifted bubble's frame in `ChannelBody`'s space, reported by the list after layout. The
    /// overlay is drawn once it is known.
    @State private var overlayBubbleFrame: CGRect?

    private let headerAvatarSize: CGFloat = 56
    private let headerSpacing: CGFloat = 8
    /// The design source tops the avatar 1pt below the top of the 44pt inline bar.
    private let headerAvatarRise: CGFloat = 43
    private let headerNameOverlap: CGFloat = 4

    init(channel: ChatChannel, repository: any ChannelRepository, currentUserID: String?, slots: ChannelSlots) {
        _store = State(initialValue: ChannelStore(
            repository: repository,
            currentUserID: currentUserID,
            canSendMessage: channel.canSendMessage,
            canReply: channel.canReply
        ))
        self.channel = channel
        self.currentUserID = currentUserID
        self.slots = slots
    }

    var body: some View {
        // Ignores the keyboard too: the composer follows the keyboard through UIKit's layout guide,
        // so SwiftUI must not shrink the list as well.
        ChannelBody(
            content: MessageListContent(
                rows: store.rows,
                topStatus: topStatus,
                canLoadPreviousPage: store.state.canLoadPreviousPage,
                repliesEnabled: store.state.canSend && store.state.canReply
            ),
            slots: slots,
            signals: signals,
            isEmpty: store.state.phase == .empty,
            canSend: store.state.canSend,
            isUnavailable: !store.state.canSendMessage,
            replyingTo: replyingTo,
            replyBarText: replyingTo.map { ReplyBarText($0, currentUserID: currentUserID) },
            topInset: (slots.header == nil ? headerHeight : 0) + (channel.isFrozen ? bannerHeight : 0),
            onReachTop: { store.send(.loadPreviousPage) },
            onRetry: { store.send(.retryPreviousPage) },
            onFailedMessageSelected: { selectedFailedMessage = $0 },
            onSend: { store.send(.sendText($0)) },
            onAttach: { store.send(.sendAttachments($0)) },
            onAttachFailure: { store.send(.attachmentsFailed(message: ChannelStore.attachmentFailureMessage)) },
            onCancelReply: { store.send(.cancelReply) },
            liftedMessageID: overlayRow?.id,
            onLiftedFrameChange: liftedFrameChanged
        )
        .ignoresSafeArea()
        .accessibilityHidden(isOverlayShown)
        // Rotation or a window resize moves every bubble; the keyboard does not change this size.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in closeOverlay() }
        .background(theme.background)
        .background { headerSlotProbe }
        .overlay(alignment: .top) {
            if channel.isFrozen {
                FrozenBanner()
                    // The list makes room for the banner so its oldest rows can scroll out from
                    // underneath.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bannerHeight = $0 }
            }
        }
        .overlay { screenState }
        .overlay(alignment: .bottom) { failedMessageDialog }
        .overlay { longPressOverlay }
        .alert(
            "Couldn't attach",
            isPresented: Binding(
                get: { store.state.attachmentError != nil },
                set: { if !$0 { store.send(.dismissAttachmentError) } }
            ),
            presenting: store.state.attachmentError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if slots.header == nil {
                VStack(spacing: -headerNameOverlap) {
                    defaultHeader
                    Text(ChannelNameFormatter.title(for: channel, currentUserID: currentUserID))
                        .font(theme.headerTitleFont)
                        .foregroundStyle(theme.headerTitleText)
                        .lineLimit(1)
                        .padding(.horizontal, 15)
                        .frame(height: 30)
                        .modifier(GlassSurface(tint: theme.background))
                        .accessibilityIdentifier("defaultChannelHeaderName")
                }
                // Drawn here rather than as a toolbar item: the inline bar clips its items to its
                // own height, which cut the avatar's top and bottom.
                .padding(.top, -headerAvatarRise)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if slots.header != nil {
                if !isHeaderSlotEmpty {
                    ToolbarItem(placement: .topBarLeading) { header }
                }
            }
        }
        .task {
            warnAboutIgnoredContextMenu()
            store.send(.start)
        }
        .onChange(of: overlayRow == nil) { _, isGone in
            if isGone { closeOverlay() }
        }
        .onDisappear { closeOverlay() }
        .onChange(of: channel.canSendMessage) { store.send(.channelChanged(channel)) }
        .onChange(of: channel.canReply) { store.send(.channelChanged(channel)) }
    }

    // MARK: - Rows

    /// Looked up in `messages` on every update, so an edit of the original redraws the bar.
    private var replyingTo: ChatMessage? {
        store.state.replyingToID.flatMap { id in store.state.messages.first { $0.id == id } }
    }

    private var topStatus: MessageListContent.TopStatus {
        if store.state.phase == .loaded(isLoadingPrevious: true) {
            return .loading
        }
        return store.state.canRetryPreviousPage ? .retry : .none
    }

    // MARK: - Failed messages

    /// Anchored to the bottom edge, which sits on the composer, so the menu rises from there like
    /// the design source's action sheet instead of pointing at whatever row is in the middle.
    private var failedMessageDialog: some View {
        Color.clear
            .frame(height: 1)
            .confirmationDialog(
                "Failed to send",
                isPresented: Binding(
                    get: { selectedFailedMessage != nil },
                    set: { if !$0 { selectedFailedMessage = nil } }
                ),
                titleVisibility: .hidden,
                presenting: selectedFailedMessage
            ) { message in
                // A failed message is always the current user's.
                if let content = signals.content(for: .failedTap, message: message, isMine: true) {
                    content
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    private var signals: MessageSignals {
        MessageSignals(
            longPress: slots.messageContextMenu,
            failedTap: slots.failedMessageActions,
            doubleTap: slots.messageDoubleTapped,
            overlay: slots.messageLongPressOverlay,
            canSend: store.state.canSend,
            canReply: { [state = store.state] in state.canAnswer($0) },
            resend: { store.send(.resendMessage(id: $0)) },
            remove: { store.send(.removeFailedMessage(id: $0)) },
            reply: { store.send(.startReply(messageID: $0)) },
            openOverlay: { id in
                if overlayMessageID == nil { overlayMessageID = id }
            }
        )
    }

    // MARK: - Long-press overlay

    private var overlayRow: MessageRowState? {
        overlayMessageID.flatMap { MessageLongPressOverlay.presentableRow(id: $0, in: store.rows) }
    }

    private var isOverlayShown: Bool {
        overlayRow != nil && overlayBubbleFrame != nil
    }

    @ViewBuilder
    private var longPressOverlay: some View {
        if let row = overlayRow, let frame = overlayBubbleFrame, let views = slots.messageLongPressOverlay {
            MessageLongPressOverlay(
                row: row,
                bubbleFrame: frame,
                slots: slots,
                signals: signals,
                views: views,
                listTopInset: slots.header == nil ? headerHeight : 0,
                onDismiss: closeOverlay
            )
            .id(row.id)
        }
    }

    private func liftedFrameChanged(_ frame: CGRect?) {
        guard overlayMessageID != nil else { return }
        guard let frame else {
            closeOverlay()
            return
        }
        overlayBubbleFrame = frame
    }

    private func closeOverlay() {
        overlayMessageID = nil
        overlayBubbleFrame = nil
    }

    private static var didWarnAboutIgnoredContextMenu = false

    private func warnAboutIgnoredContextMenu() {
        #if DEBUG
        guard slots.messageLongPressOverlay != nil, slots.messageContextMenu != nil, !Self.didWarnAboutIgnoredContextMenu else {
            return
        }
        Self.didWarnAboutIgnoredContextMenu = true
        Logger(subsystem: "AnyChatUI", category: "Channel").warning(
            "ChannelView has both messageLongPressOverlay(above:below:) and messageContextMenu(_:); the long press shows the overlay, so the context menu has no effect."
        )
        #endif
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if let slot = slots.header {
            // The toolbar item proposes less width than the content wants, which clipped a
            // slot's text away; the default header avoids it the same way.
            slot(channel)
                .fixedSize()
        } else {
            defaultHeader
        }
    }

    /// A toolbar item that is present but empty still takes the leading spot, so the slot is
    /// resolved here, without being drawn, to decide whether to add the item at all.
    @ViewBuilder
    private var headerSlotProbe: some View {
        if let slot = slots.header {
            Group(subviews: slot(channel)) { subviews in
                Color.clear
                    .onChange(of: subviews.isEmpty, initial: true) { _, isEmpty in isHeaderSlotEmpty = isEmpty }
            }
        }
    }

    private var defaultHeader: some View {
        let cover = ChannelCover.resolve(for: channel, currentUserID: currentUserID)

        return Avatar(
            .init(cover),
            size: headerAvatarSize,
            background: cover == .broadcast ? theme.broadcastCoverBackground : theme.avatarPlaceholderBackground,
            tint: cover == .broadcast ? theme.broadcastCoverTint : theme.avatarPlaceholderTint
        )
        .fixedSize()
    }

    // MARK: - Screen state

    @ViewBuilder
    private var screenState: some View {
        switch store.state.phase {
        case .loading:
            ProgressView()
                .tint(theme.accent)

        case let .error(message):
            Placeholder(
                icon: .error,
                text: message,
                tint: theme.placeholderTint,
                font: theme.messageFont,
                retry: .init(title: "Retry", tint: theme.accent) { store.send(.retry) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)

        case .empty:
            // `ChannelBody` draws it, so it ends at the composer and follows the keyboard.
            EmptyView()

        case .idle, .loaded:
            EmptyView()
        }
    }
}
