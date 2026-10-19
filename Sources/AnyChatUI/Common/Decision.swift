/// What a reducer decided for one input: the state to store and the effects to run, in order.
///
/// An ignored input is still a decision, with the state unchanged and no effects.
nonisolated struct Decision<State: Equatable & Sendable, Effect: Equatable & Sendable>: Equatable, Sendable {
    var nextState: State
    var effects: [Effect] = []
}
