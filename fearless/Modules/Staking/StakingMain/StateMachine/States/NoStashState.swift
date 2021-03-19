import Foundation

final class NoStashState: BaseStakingState {
    private(set) var rewardEstimationAmount: Decimal?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         rewardEstimationAmount: Decimal? = nil) {
        self.rewardEstimationAmount = rewardEstimationAmount

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stashItem: StashItem?) {
        if let stashItem = stashItem {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = StashState(stateMachine: stateMachine,
                                      commonData: commonData,
                                      stashItem: stashItem)

            stateMachine.transit(to: newState)
        } else {
            stateMachine?.transit(to: self)
        }
    }

    override func process(rewardEstimationAmount: Decimal?) {
        self.rewardEstimationAmount = rewardEstimationAmount

        stateMachine?.transit(to: self)
    }
}
