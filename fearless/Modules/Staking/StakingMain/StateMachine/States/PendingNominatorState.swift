import Foundation

final class PendingNominatorState: BaseStashNextState {
    private(set) var nomination: Nomination?

    private(set) var ledgerInfo: DyStakingLedger?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger?,
         nomination: Nomination?,
         totalReward: TotalRewardItem?,
         payee: RewardDestinationArg?) {
        self.ledgerInfo = ledgerInfo
        self.nomination = nomination

        super.init(stateMachine: stateMachine,
                   commonData: commonData,
                   stashItem: stashItem,
                   totalReward: totalReward,
                   payee: payee)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: DyStakingLedger?) {
        self.ledgerInfo = ledgerInfo

        if let ledgerInfo = ledgerInfo, let nomination = nomination {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = NominatorState(stateMachine: stateMachine,
                                          commonData: commonData,
                                          stashItem: stashItem,
                                          ledgerInfo: ledgerInfo,
                                          nomination: nomination,
                                          totalReward: totalReward,
                                          payee: payee)

            stateMachine.transit(to: newState)
        } else {
            stateMachine?.transit(to: self)
        }
    }

    override func process(nomination: Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo, let nomination = nomination {
            newState = NominatorState(stateMachine: stateMachine,
                                      commonData: commonData,
                                      stashItem: stashItem,
                                      ledgerInfo: ledgerInfo,
                                      nomination: nomination,
                                      totalReward: totalReward,
                                      payee: payee)
        } else if let ledgerInfo = ledgerInfo {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo,
                                   totalReward: totalReward,
                                   payee: payee)
        } else if let nomination = nomination {
            self.nomination = nomination

            newState = self
        } else {
            newState = PendingBondedState(stateMachine: stateMachine,
                                          commonData: commonData,
                                          stashItem: stashItem,
                                          totalReward: totalReward,
                                          payee: payee)
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo, let prefs = validatorPrefs {
            newState = ValidatorState(stateMachine: stateMachine,
                                      commonData: commonData,
                                      stashItem: stashItem,
                                      ledgerInfo: ledgerInfo,
                                      prefs: prefs,
                                      totalReward: totalReward,
                                      payee: payee)
        } else if let prefs = validatorPrefs {
            newState = PendingValidatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             prefs: prefs,
                                             totalReward: totalReward,
                                             payee: payee)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
