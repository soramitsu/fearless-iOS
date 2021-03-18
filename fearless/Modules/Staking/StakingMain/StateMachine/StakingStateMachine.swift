import Foundation

final class StakingStateMachine {
    private(set) var state: StakingStateProtocol

    weak var delegate: StakingStateMachineDelegate?

    init() {
        let state = InitialStakingState(stateMachine: nil, commonData: StakingStateCommonData.empty)

        self.state = state

        state.stateMachine = self
    }
}

extension StakingStateMachine: StakingStateMachineProtocol {
    func transit(to state: StakingStateProtocol) {
        self.state = state

        delegate?.stateMachineDidChangeState(self)
    }
}
