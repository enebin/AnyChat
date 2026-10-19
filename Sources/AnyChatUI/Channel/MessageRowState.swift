import Foundation
import AnyChatCore

/// A message and the presentation values derived from it and its neighbors.
///
/// Grouping and date separators depend on the messages around each one, so the list compares and
/// diffs on this type rather than on the message.
nonisolated struct MessageRowState: Hashable, Identifiable {
    enum Content: Hashable {
        case text(String)
        case attachments(Attachments)
        case system(String)
        /// Content this screen does not draw, such as a file message without attachment metadata.
        case placeholder
    }

    /// An ordinary message's attachments, grouped the way the default row stacks them.
    struct Attachments: Hashable {
        /// Images, GIFs, and videos, drawn as thumbnails.
        let media: [ChatAttachment]
        /// Every other kind, drawn as file rows below the media.
        let files: [ChatAttachment]
        /// The body drawn below the attachments, or `nil` when it is empty.
        let text: String?

        init(_ attachments: [ChatAttachment], text: String) {
            media = attachments.filter(\.isMedia)
            files = attachments.filter { !$0.isMedia }
            self.text = text.isEmpty ? nil : text
        }
    }

    let message: ChatMessage
    let isMine: Bool
    let groupPosition: MessageRowContext.GroupPosition
    /// Set only on the last row of a run, and never on a message that has not been sent.
    let timeText: String?
    /// Set on the first message of each day.
    let dateSeparator: MessageDateSeparatorContext?
    /// Set only on my own messages, on the last row of a run, when the backend tracks receipts.
    let receipt: ChatMessage.Receipt?
    /// Set on every message with `replyTo`, whether or not the channel allows replies now.
    let replyQuote: ReplyQuote?

    var id: String { message.id }

    var content: Content {
        switch message.content {
        case let .text(text):
            message.attachments.isEmpty ? .text(text) : .attachments(Attachments(message.attachments, text: text))
        case let .system(text):
            .system(text)
        case .file, .files:
            message.attachments.isEmpty ? .placeholder : .attachments(Attachments(message.attachments, text: ""))
        case .unsupported:
            .placeholder
        }
    }

    /// Builds the rows for `messages`, which must be oldest first.
    ///
    /// A row in `previous` is kept as is when its message and both neighbors are unchanged, since
    /// those are all a row depends on. Pass `previous` only when it was built for the same
    /// `currentUserID`, calendar, and locale, and for a `now` on the same day.
    static func rows(
        for messages: [ChatMessage],
        currentUserID: String?,
        now: Date,
        reusing previous: [MessageRowState] = [],
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> [MessageRowState] {
        let formatter = MessageDateFormatter(calendar: calendar, locale: locale)
        let keptIndices = keptIndices(of: messages, in: previous)

        return messages.indices.map { index in
            let earlier = index > messages.startIndex ? messages[index - 1] : nil
            let later = index < messages.endIndex - 1 ? messages[index + 1] : nil

            // Ids are unique, so a neighbor is unchanged exactly when it was kept right beside.
            if let keptIndex = keptIndices[index],
               index == messages.startIndex ? keptIndex == previous.startIndex : keptIndices[index - 1] == keptIndex - 1,
               index == messages.endIndex - 1 ? keptIndex == previous.endIndex - 1 : keptIndices[index + 1] == keptIndex + 1 {
                return previous[keptIndex]
            }
            return row(
                for: messages[index],
                after: earlier,
                before: later,
                currentUserID: currentUserID,
                now: now,
                calendar: calendar,
                formatter: formatter
            )
        }
    }

    /// For each message, the index of the row in `previous` that holds the same message unchanged.
    private static func keptIndices(of messages: [ChatMessage], in previous: [MessageRowState]) -> [Int?] {
        var previousIndexByID: [String: Int]?

        return messages.indices.map { index in
            let message = messages[index]
            let previousIndex: Int?
            // Streaming and new messages keep every other row at its index, so the dictionary is
            // built only when rows shift, as when an older page is prepended.
            if index < previous.endIndex, previous[index].id == message.id {
                previousIndex = index
            } else {
                if previousIndexByID == nil {
                    previousIndexByID = Dictionary(
                        previous.indices.map { (previous[$0].id, $0) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }
                previousIndex = previousIndexByID?[message.id]
            }
            guard let previousIndex, previous[previousIndex].message == message else {
                return nil
            }
            return previousIndex
        }
    }

    private static func row(
        for message: ChatMessage,
        after previous: ChatMessage?,
        before next: ChatMessage?,
        currentUserID: String?,
        now: Date,
        calendar: Calendar,
        formatter: MessageDateFormatter
    ) -> MessageRowState {
        let joinsPrevious = previous.map { isGrouped($0, message, calendar: calendar) } ?? false
        let joinsNext = next.map { isGrouped(message, $0, calendar: calendar) } ?? false
        let position = groupPosition(joinsPrevious: joinsPrevious, joinsNext: joinsNext)
        let isMine = isMine(message, currentUserID: currentUserID)
        let isSystem = message.content.isSystem
        let isUnsent = message.sendingStatus != nil
        // An unsent message carries local time, and a message received while it waits can be
        // later, so its day could run backwards against the row above.
        let startsDay = !isUnsent
            && (previous.map { !calendar.isDate($0.createdAt, inSameDayAs: message.createdAt) } ?? true)

        return MessageRowState(
            message: message,
            isMine: isMine,
            groupPosition: position,
            timeText: !isSystem && !isUnsent && !joinsNext ? formatter.timeText(for: message.createdAt) : nil,
            dateSeparator: startsDay ? formatter.dateSeparator(for: message.createdAt, now: now) : nil,
            receipt: !isSystem && !isUnsent && isMine && !joinsNext ? message.receipt : nil,
            replyQuote: isSystem ? nil : message.replyTo.map { ReplyQuote($0, replyIsMine: isMine, currentUserID: currentUserID) }
        )
    }

    /// Two neighbors share a bubble run when one person sent both within the same minute. Unsent
    /// messages come after every sent one, so they group only with each other.
    /// A reply starts a new run, so its quote never sits between two bubbles of one run.
    static func isGrouped(_ earlier: ChatMessage, _ later: ChatMessage, calendar: Calendar) -> Bool {
        guard later.replyTo == nil,
              !earlier.content.isSystem,
              !later.content.isSystem,
              (earlier.sendingStatus == nil) == (later.sendingStatus == nil),
              let earlierSender = earlier.sender?.id,
              earlierSender == later.sender?.id else {
            return false
        }
        return calendar.isDate(earlier.createdAt, equalTo: later.createdAt, toGranularity: .minute)
    }

    /// Both ids must be known: a backend message with no sender is never mine, even when nobody
    /// is signed in. Only this device's messages carry a sending status, so those are always mine.
    static func isMine(_ message: ChatMessage, currentUserID: String?) -> Bool {
        if message.sendingStatus != nil {
            return true
        }
        guard let senderID = message.sender?.id, let currentUserID else {
            return false
        }
        return senderID == currentUserID
    }

    var context: MessageRowContext {
        MessageRowContext(isMine: isMine, groupPosition: groupPosition)
    }

    /// Whether the sender's name goes above this row.
    var showsSenderName: Bool {
        !isMine && !message.content.isSystem && message.sender != nil
            && (groupPosition == .single || groupPosition == .first)
    }

    /// Whether the sender's picture goes beside this row.
    var showsSenderAvatar: Bool {
        !isMine && !message.content.isSystem && message.sender != nil
            && (groupPosition == .single || groupPosition == .last)
    }

    /// Whether a host's name view goes above this row. It does not need a sender or a name: the
    /// host decides what to draw without one.
    var showsSenderNameSlot: Bool {
        !isMine && !message.content.isSystem && (groupPosition == .single || groupPosition == .first)
    }

    /// Whether a host's picture shows beside this row. On the other incoming rows it is hidden but
    /// keeps its size, so the bubbles of a run line up. It does not need a sender: the host decides
    /// what to draw without one.
    var showsAvatarSlot: Bool {
        !isMine && !message.content.isSystem && (groupPosition == .single || groupPosition == .last)
    }

    /// Whether this row starts close under the one above it.
    var joinsPrevious: Bool {
        groupPosition == .middle || groupPosition == .last
    }

    private static func groupPosition(joinsPrevious: Bool, joinsNext: Bool) -> MessageRowContext.GroupPosition {
        switch (joinsPrevious, joinsNext) {
        case (false, false): .single
        case (false, true): .first
        case (true, true): .middle
        case (true, false): .last
        }
    }
}

extension ChatAttachment {
    nonisolated var isMedia: Bool {
        switch kind {
        case .image, .gif, .video: true
        case .audio, .voice, .other: false
        }
    }
}

extension ChatMessage.Content {
    nonisolated var isSystem: Bool {
        if case .system = self {
            return true
        }
        return false
    }
}
