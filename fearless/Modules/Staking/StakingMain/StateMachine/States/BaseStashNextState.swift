import Foundation

class BaseStashNextState: BaseStakingState {
    let stashItem: StashItem

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem) {
        self.stashItem = stashItem

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func process(stashItem: StashItem?) {
        guard self.stashItem != stashItem else {
            stateMachine?.transit(to: self)
            return
        }

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
