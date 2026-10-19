extension ChatMessage {
    /// Preserves an app-defined value and its concrete type for custom message rendering.
    ///
    /// Equality compares both the type and the value, so payload updates invalidate message rows.
    ///
    /// - Since: 1.0.0
    public struct CustomContent: Hashable, Sendable {
        private let storage: any Hashable & Sendable
        private let typeID: ObjectIdentifier
        private let equals: @Sendable (any Hashable & Sendable) -> Bool

        /// Stores a value that can safely cross concurrency boundaries and participate in diffing.
        ///
        /// - Since: 1.0.0
        public init<Value: Hashable & Sendable>(_ value: Value) {
            storage = value
            typeID = ObjectIdentifier(Value.self)
            equals = { other in
                guard let other = other as? Value else { return false }
                return value == other
            }
        }

        /// Retrieves the original value, or `nil` if it has a different concrete type.
        ///
        /// - Since: 1.0.0
        public func value<Value: Hashable & Sendable>(as type: Value.Type) -> Value? {
            guard typeID == ObjectIdentifier(type) else { return nil }
            return storage as? Value
        }

        /// Compares the concrete types and their stored values.
        ///
        /// - Since: 1.0.0
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.typeID == rhs.typeID && lhs.equals(rhs.storage)
        }

        /// Hashes the concrete type and its stored value.
        ///
        /// - Since: 1.0.0
        public func hash(into hasher: inout Hasher) {
            hasher.combine(typeID)
            storage.hash(into: &hasher)
        }
    }
}
