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
}
