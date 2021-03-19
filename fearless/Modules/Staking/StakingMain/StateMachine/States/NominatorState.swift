import Foundation

final class NominatorState: BaseStashNextState {
    private(set) var ledgerInfo: DyStakingLedger
    private(set) var nomination: Nomination

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger,
         nomination: Nomination,
         totalReward: TotalRewardItem?) {
        self.ledgerInfo = ledgerInfo
        self.nomination = nomination

        super.init(stateMachine: stateMachine,
                   commonData: commonData,
                   stashItem: stashItem,
                   totalReward: totalReward)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: DyStakingLedger?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            self.ledgerInfo = ledgerInfo

            newState = self
        } else {
            newState = StashState(stateMachine: stateMachine,
                                  commonData: commonData,
                                  stashItem: stashItem,
                                  ledgerInfo: nil,
                                  totalReward: totalReward)
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
            self.nomination = nomination

            newState = self
        } else {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo,
                                   totalReward: totalReward)
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let prefs = validatorPrefs {
            newState = ValidatorState(stateMachine: stateMachine,
                                      commonData: commonData,
                                      stashItem: stashItem,
                                      ledgerInfo: ledgerInfo,
                                      prefs: prefs,
                                      totalReward: totalReward)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
