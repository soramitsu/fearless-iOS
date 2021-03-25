import Foundation

final class PendingValidatorState: BaseStashNextState {
    private(set) var ledgerInfo: DyStakingLedger?
    private(set) var prefs: ValidatorPrefs?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger?,
         prefs: ValidatorPrefs?,
         totalReward: TotalRewardItem?,
         payee: RewardDestinationArg?) {
        self.ledgerInfo = ledgerInfo
        self.prefs = prefs

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

        if let ledgerInfo = ledgerInfo, let prefs = prefs {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = ValidatorState(stateMachine: stateMachine,
                                          commonData: commonData,
                                          stashItem: stashItem,
                                          ledgerInfo: ledgerInfo,
                                          prefs: prefs,
                                          totalReward: totalReward,
                                          payee: payee)

            stateMachine.transit(to: newState)
        } else {
            stateMachine?.transit(to: self)
        }
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
        } else if let ledgerInfo = ledgerInfo {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo,
                                   totalReward: totalReward,
                                   payee: payee)
        } else if let prefs = validatorPrefs {
            self.prefs = prefs

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
        } else if let nomination = nomination {
            newState = PendingNominatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             nomination: nomination,
                                             totalReward: totalReward,
                                             payee: payee)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
