import Foundation

final class PendingBondedState: BaseStashNextState {
    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: DyStakingLedger?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo,
                                   totalReward: totalReward)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
            newState = PendingNominatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: nil,
                                             nomination: nomination,
                                             totalReward: totalReward)
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
            newState = PendingValidatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: nil,
                                             prefs: prefs,
                                             totalReward: totalReward)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
