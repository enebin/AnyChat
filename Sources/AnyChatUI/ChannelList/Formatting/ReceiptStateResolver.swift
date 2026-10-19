import AnyChatCore

/// Decides which delivery receipt icon a channel row shows.
nonisolated enum ReceiptStateResolver {
    /// Returns the receipt of the last message when the current user sent it and the option is
    /// on, otherwise `nil`.
    static func receipt(
        for channel: ChatChannel,
        currentUserID: String?,
        options: ChannelListOptions
    ) -> ChatMessage.Receipt? {
        guard options.isMessageReceiptStatusEnabled,
              let lastMessage = channel.lastMessage,
              let senderID = lastMessage.sender?.id,
              senderID == currentUserID else {
            return nil
        }
        return lastMessage.receipt
    }
}
