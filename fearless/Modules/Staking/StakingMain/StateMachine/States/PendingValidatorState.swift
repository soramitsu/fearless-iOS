import Foundation

final class PendingValidatorState: BaseStashNextState {
    private(set) var ledgerInfo: DyStakingLedger?
    private(set) var prefs: ValidatorPrefs?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger? = nil,
         prefs: ValidatorPrefs? = nil) {
        self.ledgerInfo = ledgerInfo
        self.prefs = prefs

        super.init(stateMachine: stateMachine, commonData: commonData, stashItem: stashItem)
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
                                          prefs: prefs)

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
                                      prefs: prefs)
        } else if let ledgerInfo = ledgerInfo {
            newState = BondedState(stateMachine: stateMachine,
                                   commonData: commonData,
                                   stashItem: stashItem,
                                   ledgerInfo: ledgerInfo)
        } else if let prefs = validatorPrefs {
            self.prefs = prefs

            newState = self
        } else {
            newState = PendingBondedState(stateMachine: stateMachine,
                                          commonData: commonData,
                                          stashItem: stashItem)
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
                                      nomination: nomination)
        } else if let nomination = nomination {
            newState = PendingNominatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             nomination: nomination)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
