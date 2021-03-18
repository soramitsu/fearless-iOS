import Foundation

final class InitialStakingState: BaseStakingState {
    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stashItem: StashItem?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let stashItem = stashItem {
            newState = StashState(stateMachine: stateMachine,
                                  commonData: commonData,
                                  stashItem: stashItem)
        } else {
            newState = NoStashState(stateMachine: stateMachine,
                                    commonData: commonData)
        }

        stateMachine.transit(to: newState)
    }
}
