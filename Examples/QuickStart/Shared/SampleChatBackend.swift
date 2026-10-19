import Foundation
import Observation
import AnyChatUI

/// A backend that lives in memory, so the demo runs without an account or a network.
@MainActor
final class SampleChatBackend: ChatBackend {
    static let currentUserID = "me"

    let currentUserID: String? = SampleChatBackend.currentUserID

    /// Outgoing messages live here rather than in a repository, so a failed message is still
    /// there after leaving and reopening its channel.
    private let outbox = SampleOutbox()
    /// Which channels are answering now, so a screen can offer to stop the answer.
    let replies = SampleReplies()

    func makeChannelListRepository() -> any ChannelListRepository {
        SampleChannelListRepository(channels: SampleData.channels(now: Date()))
    }

    func makeChannelRepository(channelID: String) -> any ChannelRepository {
        SampleChannelRepository(
            channelID: channelID,
            messages: SampleData.messages(channelID: channelID, now: Date()),
            streamedReply: SampleData.streamedReply(channelID: channelID),
            outbox: outbox,
            replies: replies
        )
    }
}

/// Serves a fixed list a page at a time and republishes the whole list after every change.
@MainActor
final class SampleChannelListRepository: ChannelListRepository {
    private static let pageSize = 15

    private var channels: [ChatChannel]
    private var loadedCount = 0
    private var continuation: AsyncStream<[ChatChannel]>.Continuation?

    init(channels: [ChatChannel]) {
        self.channels = channels
    }

    func startObserving() -> AsyncStream<[ChatChannel]> {
        stopObserving()
        loadedCount = 0

        let (stream, continuation) = AsyncStream<[ChatChannel]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        return stream
    }

    func loadMore() async throws -> ChannelListPage {
        guard continuation != nil else {
            throw ChannelListRepositoryError.notObserving
        }
        loadedCount = min(loadedCount + Self.pageSize, channels.count)
        return ChannelListPage(channels: loadedChannels, hasNext: loadedCount < channels.count)
    }

    func leave(channelID: String) async throws {
        let index = try index(of: channelID)
        channels.remove(at: index)
        if index < loadedCount {
            loadedCount -= 1
        }
        continuation?.yield(loadedChannels)
    }

    func setNotificationLevel(_ level: ChatChannel.NotificationLevel, channelID: String) async throws {
        channels[try index(of: channelID)].notificationLevel = level
        continuation?.yield(loadedChannels)
    }

    func stopObserving() {
        continuation?.finish()
        continuation = nil
    }

    /// Changes one channel and republishes the list, the way a backend reports an update.
    func updateChannel(id: String, _ change: (inout ChatChannel) -> Void) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&channels[index])
        continuation?.yield(loadedChannels)
    }

    private var loadedChannels: [ChatChannel] {
        Array(channels.prefix(loadedCount))
    }

    private func index(of channelID: String) throws -> Int {
        guard let index = channels.firstIndex(where: { $0.id == channelID }) else {
            throw ChannelListRepositoryError.channelNotFound
        }
        return index
    }
}

/// Serves one channel's history a page at a time, newest page first.
@MainActor
final class SampleChannelRepository: ChannelRepository {
    private static let pageSize = 20
    /// Older pages arrive late, like a network fetch, so the top spinner shows and the UI tests
    /// can watch a page being added above messages already on screen.
    static let olderPageDelay: Duration = .milliseconds(1_500)
    /// Long enough that a UI test can scroll up before the reply's row appears.
    private static let replyStartDelay: Duration = .seconds(8)
    private static let replyWordInterval: Duration = .milliseconds(150)
    private static let replyID = "streamed-reply"
    /// Longer than `sendDelay`, so the answer comes after the question has been sent.
    private static let answerStartDelay: Duration = .seconds(2)
    /// Long enough that a UI test can see the pending state.
    static let sendDelay: Duration = .seconds(1)
    /// A text or an attached file name containing this word fails the first time it is sent, so the
    /// demo can show a failed message and resend it.
    static let failureKeyword = "fail"

    private let channelID: String
    /// `nil` when the channel does not exist.
    private var messages: [ChatMessage]?
    private let outbox: SampleOutbox
    private let replies: SampleReplies
    /// Sent a few words at a time after the first page, the way a streaming reply arrives.
    private let streamedReply: String?
    private var loadedCount = 0
    /// Kept apart from `loadedCount`, which stays 0 after the first page of an empty channel.
    private var hasLoadedFirstPage = false
    private var continuation: AsyncStream<[ChatMessage]>.Continuation?
    private var registration: SampleOutbox.Registration?

    init(channelID: String, messages: [ChatMessage]?, streamedReply: String? = nil, outbox: SampleOutbox, replies: SampleReplies) {
        self.channelID = channelID
        self.messages = messages
        self.streamedReply = streamedReply
        self.outbox = outbox
        self.replies = replies
    }

    func startObserving() -> AsyncStream<[ChatMessage]> {
        stopObserving()
        loadedCount = 0
        hasLoadedFirstPage = false

        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        let registration = outbox.observe(channelID: channelID) { [weak self] in self?.publish() }
        self.registration = registration
        // The screen ends the stream by cancelling its task without calling `stopObserving()`.
        continuation.onTermination = { [outbox] _ in
            Task { @MainActor in outbox.stopObserving(registration) }
        }
        return stream
    }

    func loadPrevious() async throws -> MessagePage {
        guard let continuation else {
            throw ChannelRepositoryError.notObserving
        }
        guard let messages else {
            throw ChannelRepositoryError.channelNotFound
        }
        if loadedCount > 0 {
            try await Task.sleep(for: Self.olderPageDelay)
        }
        let isFirstPage = loadedCount == 0
        loadedCount = min(loadedCount + Self.pageSize, messages.count)
        hasLoadedFirstPage = true
        let page = MessagePage(messages: loadedMessages, hasPrevious: loadedCount < messages.count)
        continuation.yield(page.messages)
        if isFirstPage, let streamedReply, !messages.contains(where: { $0.id == Self.replyID }) {
            stream(streamedReply, id: Self.replyID, after: Self.replyStartDelay, into: continuation)
        }
        return page
    }

    func sendMessage(text: String, replyTo: String?) {
        var message = ChatMessage(id: UUID().uuidString, sender: SampleData.me, createdAt: Date(), content: .text(text))
        message.replyTo = replyTo.map(reference(to:))
        message.sendingStatus = .pending
        outbox.add(message, channelID: channelID)
        let fails = text.localizedCaseInsensitiveContains(Self.failureKeyword)
        deliver(message.id, fails: fails)
        if streamedReply != nil, !fails, let continuation {
            stream(SampleData.answerText, id: UUID().uuidString, after: Self.answerStartDelay, into: continuation)
        }
    }

    /// Keeps the picked files where they are: the sample has no upload, so the sent message points
    /// at the local copies.
    func sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?) {
        var message = ChatMessage(
            id: UUID().uuidString,
            sender: SampleData.me,
            createdAt: Date(),
            attachments: attachments.map { outgoing in
                ChatAttachment(id: UUID().uuidString, kind: outgoing.kind, url: outgoing.fileURL, fileName: outgoing.fileName)
            }
        )
        message.replyTo = replyTo.map(reference(to:))
        message.sendingStatus = .pending
        outbox.add(message, channelID: channelID)
        let fails = attachments.contains { $0.fileName.localizedCaseInsensitiveContains(Self.failureKeyword) }
        deliver(message.id, fails: fails)
    }

    func resendMessage(id: String) {
        guard outbox.sendingStatus(of: id, channelID: channelID) == .failed else {
            return
        }
        outbox.setSendingStatus(.pending, of: id, channelID: channelID)
        deliver(id, fails: false)
    }

    func removeFailedMessage(id: String) {
        guard outbox.sendingStatus(of: id, channelID: channelID) == .failed else {
            return
        }
        outbox.remove(id, channelID: channelID)
    }

    func stopObserving() {
        continuation?.finish()
        continuation = nil
        if let registration {
            outbox.stopObserving(registration)
        }
        registration = nil
    }
}

private extension SampleChannelRepository {
    var loadedMessages: [ChatMessage] {
        let sent = Array((messages ?? []).suffix(loadedCount)) + outbox.sentMessages(channelID: channelID)
        return sent.sorted { $0.createdAt < $1.createdAt } + outbox.unsentMessages(channelID: channelID)
    }

    /// Searches the whole history, not just the pages read: a real backend knows its own messages.
    func reference(to id: String) -> ChatMessage.ReplyReference {
        let known = (messages ?? []) + outbox.sentMessages(channelID: channelID)
        guard let original = known.first(where: { $0.id == id }) else {
            return .unavailable(messageID: id)
        }
        return ChatMessage.ReplyReference(
            messageID: original.id,
            sender: original.sender,
            content: original.content,
            attachments: original.attachments
        )
    }

    /// Waits for the first page: a snapshot sent before it would replace that page with less.
    func publish() {
        guard hasLoadedFirstPage else {
            return
        }
        continuation?.yield(loadedMessages)
    }

    /// Finishes a send after a delay. It runs even when this repository is gone, as a real backend
    /// keeps sending after the screen closes; the outbox tells whichever repository observes now.
    func deliver(_ id: String, fails: Bool) {
        Task { [outbox, channelID] in
            try? await Task.sleep(for: Self.sendDelay)
            outbox.setSendingStatus(fails ? .failed : nil, of: id, channelID: channelID)
        }
    }

    /// Grows one message in place, sending a snapshot with the same id after each word. The channel
    /// counts as answering from the start of the wait, as an assistant that is still thinking does.
    func stream(
        _ reply: String,
        id: String,
        after startDelay: Duration,
        into continuation: AsyncStream<[ChatMessage]>.Continuation
    ) {
        let words = reply.split(separator: " ")
        let task = Task { [weak self] in
            try? await Task.sleep(for: startDelay)
            for count in 1...words.count {
                guard !Task.isCancelled, let self else {
                    return
                }
                setReply(words.prefix(count).joined(separator: " "), id: id)
                continuation.yield(loadedMessages)
                try? await Task.sleep(for: Self.replyWordInterval)
            }
        }
        replies.start(task, channelID: channelID)
        Task { [replies, channelID] in
            await task.value
            replies.finish(task, channelID: channelID)
        }
        // Ending this stream stops only this reply; a newer observation keeps its own.
        let releaseObservation = continuation.onTermination
        continuation.onTermination = { termination in
            releaseObservation?(termination)
            task.cancel()
        }
    }

    func setReply(_ text: String, id: String) {
        guard var messages else {
            return
        }
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = .text(text)
        } else {
            messages.append(ChatMessage(id: id, sender: SampleData.assistant, createdAt: Date(), content: .text(text)))
            loadedCount += 1
        }
        self.messages = messages
    }
}

/// The replies streaming in now, per channel. Stopping one keeps the words already sent.
@MainActor
@Observable
final class SampleReplies {
    private var tasks: [String: Task<Void, Never>] = [:]

    func isResponding(channelID: String) -> Bool {
        tasks[channelID] != nil
    }

    func stop(channelID: String) {
        tasks.removeValue(forKey: channelID)?.cancel()
    }

    fileprivate func start(_ task: Task<Void, Never>, channelID: String) {
        tasks[channelID]?.cancel()
        tasks[channelID] = task
    }

    /// A reply that ends late may already have been replaced by a newer one, which stays.
    fileprivate func finish(_ task: Task<Void, Never>, channelID: String) {
        guard tasks[channelID] == task else {
            return
        }
        tasks[channelID] = nil
    }
}

/// Messages the current user sent, per channel, in the order they were sent.
///
/// Every change is reported to the repository observing that channel now, which may not be the
/// one that sent the message.
@MainActor
final class SampleOutbox {
    /// One observation. Its identity tells a stream that ended late from the observation that
    /// replaced it on a Retry.
    final class Registration: Sendable {
        let channelID: String

        init(channelID: String) {
            self.channelID = channelID
        }
    }

    private struct Observer {
        let registration: Registration
        let changed: () -> Void
    }

    private var messagesByChannel: [String: [ChatMessage]] = [:]
    private var observers: [String: Observer] = [:]

    func observe(channelID: String, changed: @escaping () -> Void) -> Registration {
        let registration = Registration(channelID: channelID)
        observers[channelID] = Observer(registration: registration, changed: changed)
        return registration
    }

    /// Leaves a newer registration alone.
    func stopObserving(_ registration: Registration) {
        if observers[registration.channelID]?.registration === registration {
            observers[registration.channelID] = nil
        }
    }

    func sentMessages(channelID: String) -> [ChatMessage] {
        (messagesByChannel[channelID] ?? []).filter { $0.sendingStatus == nil }
    }

    func unsentMessages(channelID: String) -> [ChatMessage] {
        (messagesByChannel[channelID] ?? []).filter { $0.sendingStatus != nil }
    }

    func add(_ message: ChatMessage, channelID: String) {
        messagesByChannel[channelID, default: []].append(message)
        observers[channelID]?.changed()
    }

    func sendingStatus(of id: String, channelID: String) -> ChatMessage.SendingStatus? {
        messagesByChannel[channelID]?.first { $0.id == id }?.sendingStatus
    }

    func setSendingStatus(_ status: ChatMessage.SendingStatus?, of id: String, channelID: String) {
        guard let index = messagesByChannel[channelID]?.firstIndex(where: { $0.id == id }) else {
            return
        }
        messagesByChannel[channelID]?[index].sendingStatus = status
        if status == nil {
            messagesByChannel[channelID]?[index].receipt = .sent
        }
        observers[channelID]?.changed()
    }

    func remove(_ id: String, channelID: String) {
        messagesByChannel[channelID]?.removeAll { $0.id == id }
        observers[channelID]?.changed()
    }
}

enum SampleData {
    static let assistantChannelID = "assistant"
    static let assistantChannelName = "Assistant"
    static let assistant = ChatSender(id: "assistant", name: "Assistant")
    static let streamedReplyText = "Replies like this one arrive a few words at a time. The row grows in place, and the list stays on the newest message while it does."

    /// The assistant's answer to every text sent to it: a numbered list taller than the screen, so
    /// a list that keeps the question at the top lets it run past the bottom edge.
    static let answerText = (1...30).map { "Point \($0)" }.joined(separator: "\n")

    /// The assistant channel answers with a reply that streams in; other channels do not.
    static func streamedReply(channelID: String) -> String? {
        channelID == assistantChannelID ? streamedReplyText : nil
    }

    static let firstChannelName = "Design team"
    /// A channel without messages, so the demo can show the empty state.
    static let emptyChannelID = "book-club"
    static let lastPhotoCaption = "The view from the office"

    /// Bundled files, so attachments load without the network.
    private enum Media {
        static let landscape = attachment("landscape", "jpg", .image)
        static let portrait = attachment("portrait", "jpg", .image)
        static let wave = attachment("wave", "gif", .gif)
        static let clip = attachment("clip", "mp4", .video)
        static let report = ChatAttachment(
            id: "report",
            kind: .other,
            url: URL(string: "https://example.com/files/quarterly-report-final-version.pdf")!,
            fileName: "quarterly-report-final-version.pdf",
            fileSize: 482_000
        )
        static let memo = ChatAttachment(
            id: "memo",
            kind: .audio,
            url: URL(string: "https://example.com/files/memo.m4a")!,
            fileName: "memo.m4a"
        )

        private static func attachment(_ name: String, _ ext: String, _ kind: ChatMessage.FileKind) -> ChatAttachment {
            ChatAttachment(
                id: name,
                kind: kind,
                url: Bundle.main.url(forResource: name, withExtension: ext)!,
                fileName: "\(name).\(ext)"
            )
        }
    }

    private static let people = [
        ChatSender(id: "alice", name: "Alice"),
        ChatSender(id: "bob", name: "Bob"),
        ChatSender(id: "carol", name: "Carol"),
        ChatSender(id: "dave", name: "Dave"),
        ChatSender(id: "erin", name: "Erin")
    ]

    static let me = ChatSender(id: SampleChatBackend.currentUserID, name: "Me")

    static let pollChannelName = "Lunch"
    /// The lunch channel's last message carries it as custom content, with its question as the text
    /// fallback.
    static let lunchPoll = SamplePoll(
        question: "Where should we eat on Friday?",
        options: [
            SamplePoll.Option(title: "Noodle bar", votes: 3),
            SamplePoll.Option(title: "Taco truck", votes: 5),
            SamplePoll.Option(title: "Salad place", votes: 1)
        ]
    )

    /// The first channel's last message and the lunch poll carry these in `attributes`.
    static let shipItReactions = SampleReactions(reactions: [
        SampleReactions.Reaction(emoji: "❤️", name: "Heart", count: 2),
        SampleReactions.Reaction(emoji: "👍", name: "Thumbs up", count: 1)
    ])
    static let lunchPollReactions = SampleReactions(reactions: [
        SampleReactions.Reaction(emoji: "🌮", name: "Taco", count: 3)
    ])

    /// Thirty-three channels, newest first, covering every row decoration the list can show.
    static func channels(now: Date) -> [ChatChannel] {
        let hour: TimeInterval = 3_600
        var channels = [
            ChatChannel(
                id: assistantChannelID,
                name: assistantChannelName,
                createdAt: now.addingTimeInterval(-7 * 24 * hour),
                memberCount: 2,
                members: [me, assistant],
                lastMessage: message("Ask me anything", from: assistant, at: now.addingTimeInterval(-0.1 * hour)),
                notificationLevel: .all,
                canLeave: true
            ),
            ChatChannel(
                id: "design",
                name: firstChannelName,
                createdAt: now.addingTimeInterval(-90 * 24 * hour),
                memberCount: 4,
                members: [me] + people.prefix(3),
                lastMessage: message("Ship it", from: people[0], at: now.addingTimeInterval(-0.2 * hour))
                    .reacted(shipItReactions),
                unreadMessageCount: 3,
                unreadMentionCount: 1,
                notificationLevel: .all,
                canLeave: true,
                canReply: true
            ),
            ChatChannel(
                id: "bob",
                createdAt: now.addingTimeInterval(-30 * 24 * hour),
                memberCount: 2,
                members: [me, people[1]],
                lastMessage: ChatMessage(
                    id: "bob-last",
                    sender: me,
                    createdAt: now.addingTimeInterval(-2 * hour),
                    text: lastPhotoCaption,
                    attachments: [Media.landscape],
                    receipt: .read
                ),
                notificationLevel: .all,
                canLeave: true,
                canReply: true
            ),
            ChatChannel(
                id: emptyChannelID,
                name: "Book club",
                createdAt: now.addingTimeInterval(-3 * hour),
                memberCount: 3,
                members: [me] + people.prefix(2),
                notificationLevel: .all,
                canLeave: true,
                canReply: true
            ),
            ChatChannel(
                id: "announcements",
                name: "Announcements",
                createdAt: now.addingTimeInterval(-200 * 24 * hour),
                memberCount: 3_200,
                lastMessage: message(.system("Maintenance tonight at 10 PM"), from: nil, at: now.addingTimeInterval(-26 * hour)),
                unreadMessageCount: 120,
                notificationLevel: .off,
                isBroadcast: true,
                canLeave: true,
                canSendMessage: false
            ),
            ChatChannel(
                id: "lunch",
                name: pollChannelName,
                createdAt: now.addingTimeInterval(-10 * 24 * hour),
                memberCount: 4,
                members: [me] + people.prefix(3),
                lastMessage: ChatMessage(
                    id: "lunch-poll",
                    sender: people[2],
                    createdAt: now.addingTimeInterval(-30 * hour),
                    content: .text("Poll: \(lunchPoll.question)"),
                    customContent: lunchPoll
                )
                .reacted(lunchPollReactions),
                notificationLevel: .all,
                canLeave: true,
                canReply: true
            ),
            ChatChannel(
                id: "archive",
                name: "Archive",
                createdAt: now.addingTimeInterval(-400 * 24 * hour),
                memberCount: 5,
                members: [me] + people,
                lastMessage: message(.file(.voice), from: people[4], at: now.addingTimeInterval(-40 * 24 * hour)),
                notificationLevel: .all,
                isFrozen: true,
                canLeave: true,
                canSendMessage: false
            ),
            ChatChannel(
                id: "updates",
                name: "Product updates",
                createdAt: now.addingTimeInterval(-60 * 24 * hour),
                lastMessage: message(.text("Version 1.0 is out"), from: nil, at: now.addingTimeInterval(-50 * 24 * hour))
            )
        ]

        for number in 1...25 {
            let person = people[number % people.count]
            channels.append(
                ChatChannel(
                    id: "topic-\(number)",
                    name: "Topic \(number)",
                    createdAt: now.addingTimeInterval(-500 * 24 * hour),
                    memberCount: 3,
                    members: [me, person, people[(number + 1) % people.count]],
                    lastMessage: message(
                        "Message \(number) from \(person.name ?? person.id)",
                        from: person,
                        at: now.addingTimeInterval(-Double(number + 2) * 24 * hour)
                    ),
                    notificationLevel: .all,
                    canLeave: true,
                    canReply: true
                )
            )
        }

        return channels.sorted { latestActivity($0) > latestActivity($1) }
    }

    private static func latestActivity(_ channel: ChatChannel) -> Date {
        channel.lastMessage?.createdAt ?? channel.createdAt
    }

    /// Sixty-one messages over three days that end with the channel's last message, none for the empty
    /// channel, or `nil` when no channel has this id. Each sender writes three messages seconds apart, so the list shows runs.
    /// Bob's channel adds one message per attachment layout before its last message.
    static func messages(channelID: String, now: Date) -> [ChatMessage]? {
        guard let channel = channels(now: now).first(where: { $0.id == channelID }) else {
            return nil
        }
        guard channelID != emptyChannelID else {
            return []
        }
        let lastMessage = channel.lastMessage ?? message("Welcome", from: nil, at: channel.createdAt)
        let senders: [ChatSender?] = channel.members.isEmpty ? [nil] : channel.members
        let count = 60
        let spacing: TimeInterval = 72 * 3_600 / Double(count)

        var messages = [
            ChatMessage(
                id: "\(channelID)-0",
                createdAt: lastMessage.createdAt.addingTimeInterval(-Double(count) * spacing),
                content: .system("\(channel.name ?? "This channel") was created")
            )
        ]
        for index in 1..<count {
            let sender = senders[(index / 3) % senders.count]
            messages.append(
                ChatMessage(
                    id: "\(channelID)-\(index)",
                    sender: sender,
                    createdAt: lastMessage.createdAt.addingTimeInterval(
                        -Double(count - index / 3 * 3) * spacing + Double(index % 3) * 10
                    ),
                    content: .text(sampleText(index: index, senderName: sender?.name ?? "the channel")),
                    receipt: sender?.id == SampleChatBackend.currentUserID ? .read : nil
                )
            )
        }
        messages += attachmentMessages(channelID: channelID, before: lastMessage.createdAt)
        messages += replyMessages(channelID: channelID, before: lastMessage.createdAt)
        messages.append(lastMessage)
        return messages
    }

    /// One of each attachment layout, sent a few minutes apart so none of them join a run.
    private static func attachmentMessages(channelID: String, before date: Date) -> [ChatMessage] {
        guard channelID == "bob" else { return [] }
        let bob = people[1]
        let layouts: [(ChatSender, String, [ChatAttachment])] = [
            (bob, "", [Media.landscape]),
            (bob, "", [Media.portrait, Media.landscape, Media.wave]),
            (me, "", [Media.clip]),
            (me, "", [Media.landscape, Media.portrait]),
            (bob, "Here is the report", [Media.report]),
            (me, "", [Media.memo])
        ]
        return layouts.enumerated().map { index, layout in
            let (sender, text, attachments) = layout
            return ChatMessage(
                id: "\(channelID)-attachment-\(index)",
                sender: sender,
                createdAt: date.addingTimeInterval(-Double(layouts.count - index) * 120),
                text: text,
                attachments: attachments,
                receipt: sender.id == SampleChatBackend.currentUserID ? .read : nil
            )
        }
    }

    /// Replies to the current user, by the current user, to another member, to a photo, and to a
    /// deleted message, sent a few minutes apart.
    private static func replyMessages(channelID: String, before date: Date) -> [ChatMessage] {
        guard channelID == "lunch" else { return [] }
        let alice = people[0], bob = people[1], carol = people[2]
        let question = ChatMessage(id: "lunch-reply-question", sender: alice, createdAt: date, content: .text("Tacos again on Friday?"))
        let photo = ChatMessage(id: "lunch-reply-photo", sender: alice, createdAt: date, text: "", attachments: [Media.landscape])
        let mine = ChatMessage(id: "lunch-reply-mine", sender: me, createdAt: date, content: .text("Works for me, as long as we leave by noon."))
        let script: [(ChatMessage, ChatMessage.ReplyReference?)] = [
            (question, nil),
            (mine, reference(to: question)),
            (ChatMessage(id: "lunch-reply-to-me", sender: bob, createdAt: date, content: .text("Noon is perfect.")), reference(to: mine)),
            (photo, nil),
            (ChatMessage(id: "lunch-reply-to-photo", sender: carol, createdAt: date, content: .text("That patio looks great")), reference(to: photo)),
            (ChatMessage(id: "lunch-reply-to-deleted", sender: bob, createdAt: date, content: .text("Ha, never mind then")), .unavailable(messageID: "lunch-deleted"))
        ]
        return script.enumerated().map { index, entry in
            var message = entry.0
            message.createdAt = date.addingTimeInterval(-Double(script.count - index) * 120)
            message.replyTo = entry.1
            message.receipt = message.sender?.id == SampleChatBackend.currentUserID ? .read : nil
            return message
        }
    }

    private static func reference(to original: ChatMessage) -> ChatMessage.ReplyReference {
        ChatMessage.ReplyReference(messageID: original.id, sender: original.sender, content: original.content, attachments: original.attachments)
    }

    /// Rows of 1, 2, 3, 4 and 10 lines, and a paragraph that wraps on its own, so an older page
    /// lands with heights its estimate gets wrong. Every text starts with "Message N from".
    private static func sampleText(index: Int, senderName: String) -> String {
        let first = "Message \(index) from \(senderName)"
        let extraLines: Int
        switch index % 6 {
        case 1: extraLines = 1
        case 2: extraLines = 2
        case 3: extraLines = 3
        case 4: extraLines = 9
        case 5:
            return first + ". This one runs on as a single paragraph without line breaks, so it wraps to "
                + "however many lines the bubble's width allows."
        default: extraLines = 0
        }
        return ([first] + (0..<extraLines).map { "Line \($0 + 2)" }).joined(separator: "\n")
    }

    private static func message(_ text: String, from sender: ChatSender?, at date: Date) -> ChatMessage {
        message(.text(text), from: sender, at: date)
    }

    private static func message(
        _ content: ChatMessage.Content,
        from sender: ChatSender?,
        at date: Date,
        receipt: ChatMessage.Receipt? = nil
    ) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, sender: sender, createdAt: date, content: content, receipt: receipt)
    }
}

private extension ChatMessage {
    func reacted(_ reactions: SampleReactions) -> ChatMessage {
        var message = self
        message.attributes[SampleReactions.self] = reactions
        return message
    }
}
