import Foundation
import Web3

final class ParachainState: BaseStakingState {
    private(set) var rewardEstimationAmount: Decimal?
    var moreHandler: ((ParachainStakingDelegationInfo) -> Void)?
    var statusHandler: (() -> Void)?

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData,
        rewardEstimationAmount: Decimal? = nil
    ) {
        self.rewardEstimationAmount = rewardEstimationAmount

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    private(set) var delegationInfos: [ParachainStakingDelegationInfo]?
    private(set) var topDelegations: [AccountAddress: ParachainStakingDelegations]?
    private(set) var bottomDelegations: [AccountAddress: ParachainStakingDelegations]?
    private(set) var requests: [AccountAddress: [ParachainStakingScheduledRequest]]?
    private(set) var round: ParachainStakingRoundInfo?
    private(set) var currentBlock: UInt32?

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    func processHandlers(moreHandler: @escaping (ParachainStakingDelegationInfo) -> Void, statusHandler: @escaping () -> Void) {
        self.moreHandler = moreHandler
        self.statusHandler = statusHandler
    }

    override func process(delegationInfos: [ParachainStakingDelegationInfo]?) {
        self.delegationInfos = delegationInfos

        stateMachine?.transit(to: self)
    }

    override func process(scheduledRequests: [AccountAddress: [ParachainStakingScheduledRequest]]?) {
        requests = scheduledRequests

        stateMachine?.transit(to: self)
    }

    override func process(bottomDelegations: [AccountAddress: ParachainStakingDelegations]?) {
        self.bottomDelegations = bottomDelegations

        stateMachine?.transit(to: self)
    }

    override func process(topDelegations: [AccountAddress: ParachainStakingDelegations]?) {
        self.topDelegations = topDelegations

        stateMachine?.transit(to: self)
    }

    override func process(roundInfo: ParachainStakingRoundInfo?) {
        round = roundInfo

        stateMachine?.transit(to: self)
    }

    override func process(currentBlock: UInt32?) {
        self.currentBlock = currentBlock

        stateMachine?.transit(to: self)
    }

    override func process(rewardEstimationAmount: Decimal?) {
        self.rewardEstimationAmount = rewardEstimationAmount

        stateMachine?.transit(to: self)
    }
}
