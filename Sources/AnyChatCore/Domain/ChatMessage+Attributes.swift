extension ChatMessage {
    /// App-defined state about a message, such as "reported" or "pinned", holding at most one
    /// value per type.
    ///
    /// Attributes never pick a renderer; `customContent` does. Read and write a value by its type:
    ///
    /// ```swift
    /// message.attributes[Moderation.self]?.isReported
    /// message.attributes[Moderation.self] = Moderation(isReported: true)
    /// message.attributes[Moderation.self] = nil
    /// ```
    ///
    /// Equality compares every type and value, so a changed attribute in a snapshot with the same
    /// message `id` updates the row in place.
    ///
    /// - Since: 1.0.0
    public struct Attributes: Hashable, Sendable {
        private var values: [ObjectIdentifier: CustomContent]

        /// Creates an empty set of attributes.
        ///
        /// - Since: 1.0.0
        public init() {
            values = [:]
        }

        /// The value stored for `type`, or `nil` if there is none. Assigning `nil` removes it.
        ///
        /// - Since: 1.0.0
        public subscript<Value: Hashable & Sendable>(type: Value.Type) -> Value? {
            get { values[ObjectIdentifier(type)]?.value(as: type) }
            set { values[ObjectIdentifier(type)] = newValue.map(CustomContent.init) }
        }
    }
}
