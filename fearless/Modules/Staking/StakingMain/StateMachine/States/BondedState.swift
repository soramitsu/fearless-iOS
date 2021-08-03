import Foundation

final class BondedState: BaseStashNextState {
    private(set) var ledgerInfo: StakingLedger

    private(set) var rewardEstimationAmount: Decimal?

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData,
        stashItem: StashItem,
        ledgerInfo: StakingLedger,
        totalReward: TotalRewardItem?,
        rewardEstimationAmount: Decimal? = nil,
        payee: RewardDestinationArg?
    ) {
        self.ledgerInfo = ledgerInfo
        self.rewardEstimationAmount = rewardEstimationAmount

        super.init(
            stateMachine: stateMachine,
            commonData: commonData,
            stashItem: stashItem,
            totalReward: totalReward,
            payee: payee
        )
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(rewardEstimationAmount: Decimal?) {
        self.rewardEstimationAmount = rewardEstimationAmount

        stateMachine?.transit(to: self)
    }

    override func process(ledgerInfo: StakingLedger?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            self.ledgerInfo = ledgerInfo

            newState = self
        } else {
            newState = StashState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
                totalReward: totalReward
            )
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
            newState = NominatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                nomination: nomination,
                totalReward: totalReward,
                payee: payee
            )
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let prefs = validatorPrefs {
            newState = ValidatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                prefs: prefs,
                totalReward: totalReward,
                payee: payee
            )
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
