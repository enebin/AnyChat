import AnyChatCore

nonisolated struct MessageListContent: Equatable, Sendable {
    enum TopStatus: Hashable, Sendable {
        case none
        case loading
        case retry
    }

    var rows: [MessageRowState] = []
    var topStatus: TopStatus = .none
    var canLoadPreviousPage = false
    /// Whether replying is possible at all now (`canSend` and `canReply`). Rows read it through
    /// the signals while they are built, so a change rebuilds every row.
    var repliesEnabled = false

    /// The row a send added: the current user's pending row that `previous` did not have. A
    /// sending call puts it in the next snapshot (adapter rule 15).
    func sentRowID(after previous: MessageListContent) -> String? {
        let previousIDs = Set(previous.rows.map(\.id))
        return rows.last { row in
            row.isMine && row.message.sendingStatus == .pending && !previousIDs.contains(row.id)
        }?.id
    }
}
