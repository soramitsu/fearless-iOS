import Foundation

final class PendingNominatorState: BaseStashNextState {
    private(set) var nomination: Nomination?

    private(set) var ledgerInfo: DyStakingLedger?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger? = nil,
         nomination: Nomination? = nil) {
        self.ledgerInfo = ledgerInfo
        self.nomination = nomination

        super.init(stateMachine: stateMachine, commonData: commonData, stashItem: stashItem)
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
                                          nomination: nomination)

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
                                      nomination: nomination)
        } else if let ledgerInfo = ledgerInfo {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo)
        } else if let nomination = nomination {
            self.nomination = nomination

            newState = self
        } else {
            newState = PendingBondedState(stateMachine: stateMachine,
                                          commonData: commonData,
                                          stashItem: stashItem)
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
                                      prefs: prefs)
        } else if let prefs = validatorPrefs {
            newState = PendingValidatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             prefs: prefs)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
