import Foundation

class BaseStashNextState: BaseStakingState {
    let stashItem: StashItem
    private(set) var totalReward: TotalRewardItem?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         totalReward: TotalRewardItem?) {
        self.stashItem = stashItem
        self.totalReward = totalReward

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
                                  stashItem: stashItem,
                                  ledgerInfo: nil,
                                  totalReward: nil)
        } else {
            newState = NoStashState(stateMachine: stateMachine,
                                    commonData: commonData)
        }

        stateMachine.transit(to: newState)
    }

    override func process(totalReward: TotalRewardItem?) {
        self.totalReward = totalReward

        stateMachine?.transit(to: self)
    }
}
