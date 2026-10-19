import AnyChatCore
import AnyChatDesignSystem
import SwiftUI

/// A list of the current user's channels.
///
/// Register a backend once near the root with `chatBackend(_:)`; the list loads from it. The
/// host app owns connecting that backend. Wrap the list in your own `NavigationStack`.
///
/// ```swift
/// NavigationStack {
///     ChannelListView()
///         .onChannelSelected { channel in ... }
/// }
/// .chatBackend(backend)
/// ```
///
/// - Since: 1.0.0
public struct ChannelListView: View {
    static let defaultTitle = "Messages"

    private let options: ChannelListOptions
    /// Set by the overriding initializer, which bypasses the environment.
    private let override: Override?

    var slots = ChannelListSlots()
    var callbacks = ChannelListCallbacks()
    var title = defaultTitle

    @Environment(\.chatBackend) private var backend
    @Environment(\.channelListTheme) private var theme

    private struct Override {
        let repository: any ChannelListRepository
        let currentUserID: String?
    }

    /// Creates a channel list that loads from the backend registered with `chatBackend(_:)`.
    ///
    /// - Parameter options: Feature switches for the rows.
    ///
    /// - Since: 1.0.0
    public init(options: ChannelListOptions = ChannelListOptions()) {
        self.options = options
        self.override = nil
    }

    /// Creates a channel list around a repository of your own, ignoring any registered backend.
    ///
    /// Backend adapters use this to offer screen-specific entry points, such as a custom query.
    ///
    /// - Since: 1.0.0
    public init(
        repository: any ChannelListRepository,
        currentUserID: String?,
        options: ChannelListOptions = ChannelListOptions()
    ) {
        self.options = options
        self.override = Override(repository: repository, currentUserID: currentUserID)
    }

    public var body: some View {
        if let override {
            content(repository: override.repository, currentUserID: override.currentUserID)
        } else if let backend {
            // A newly registered backend, e.g. after signing out, must not reuse the old store.
            content(repository: backend.makeChannelListRepository(), currentUserID: backend.currentUserID)
                .id(ObjectIdentifier(backend))
        } else {
            missingBackend
        }
    }

    private func content(repository: any ChannelListRepository, currentUserID: String?) -> some View {
        ChannelListContent(
            repository: repository,
            currentUserID: currentUserID,
            options: options,
            slots: slots,
            callbacks: callbacks,
            title: title
        )
    }

    private var missingBackend: some View {
        MissingBackendView(
            screenName: "ChannelListView",
            tint: theme.placeholderTint,
            font: theme.messageFont,
            background: theme.background
        )
        .navigationTitle(title)
    }
}

#Preview("Missing backend") {
    NavigationStack {
        ChannelListView()
    }
}
