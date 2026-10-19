/// One chat backend, registered once near the app's root with `View.chatBackend(_:)`.
///
/// Screens ask it for their repositories when they appear. Main-actor isolated like the
/// repositories it makes; `Sendable` so it can travel through the SwiftUI environment.
///
/// - Since: 1.0.0
@MainActor
public protocol ChatBackend: AnyObject, Sendable {
    /// The signed-in user, or `nil` when nobody is signed in.
    ///
    /// - Since: 1.0.0
    var currentUserID: String? { get }

    /// Makes the repository behind one channel list screen.
    ///
    /// - Since: 1.0.0
    func makeChannelListRepository() -> any ChannelListRepository

    /// Makes the repository behind one channel's message list.
    ///
    /// Do no backend work here; open resources in `ChannelRepository.startObserving()`.
    ///
    /// - Since: 1.0.0
    func makeChannelRepository(channelID: String) -> any ChannelRepository
}
