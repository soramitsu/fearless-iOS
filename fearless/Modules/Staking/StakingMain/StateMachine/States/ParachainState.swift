import Foundation
import BigInt

final class ParachainState: BaseStakingState {
    var moreHandler: ((ParachainStakingDelegationInfo) -> Void)?
    var statusHandler: (() -> Void)?

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData
    ) {
        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    private(set) var delegationInfos: [ParachainStakingDelegationInfo]?
    private(set) var bottomDelegations: [AccountAddress: ParachainStakingDelegations]?
    private(set) var requests: [ParachainStakingScheduledRequest]?
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

    override func process(scheduledRequests: [ParachainStakingScheduledRequest]?) {
        requests = scheduledRequests

        stateMachine?.transit(to: self)
    }

    override func process(bottomDelegations: [AccountAddress: ParachainStakingDelegations]?) {
        self.bottomDelegations = bottomDelegations

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
}
