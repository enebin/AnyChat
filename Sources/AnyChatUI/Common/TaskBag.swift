import Synchronization

/// A cancellable `Task` store that keeps at most one task per ID.
///
/// Starting a new task with an existing ID cancels the previous one. Operations run on the
/// main actor, where the store and the repositories live.
///
/// - Note: This type stays `nonisolated` so `deinit` can cancel everything when the owning
///   store is released.
nonisolated final class TaskBag<ID: Hashable & Sendable>: Sendable {
    private let tasks = Mutex<[ID: Task<Void, Never>]>([:])

    init() {}

    /// Cancels any existing task for `id` and starts a new one.
    func start(_ id: ID, operation: @escaping @MainActor () async -> Void) {
        let task = Task { @MainActor in
            await operation()
        }

        tasks.withLock { tasks in
            tasks[id]?.cancel()
            tasks[id] = task
        }
    }

    /// Cancels the task for `id` and removes it.
    func cancel(_ id: ID) {
        tasks.withLock { tasks in
            tasks[id]?.cancel()
            tasks[id] = nil
        }
    }

    /// Cancels every stored task and empties the bag.
    func cancelAll() {
        tasks.withLock { tasks in
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }

    deinit {
        cancelAll()
    }
}
