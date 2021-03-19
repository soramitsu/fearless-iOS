import Foundation

final class StashState: BaseStakingState {
    private(set) var stashItem: StashItem

    private(set) var ledgerInfo: DyStakingLedger?

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger? = nil) {
        self.stashItem = stashItem
        self.ledgerInfo = ledgerInfo

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stashItem: StashItem?) {
        if let stashItem = stashItem {
            self.stashItem = stashItem

            stateMachine?.transit(to: self)
        } else {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = NoStashState(stateMachine: stateMachine,
                                        commonData: commonData)

            stateMachine.transit(to: newState)
        }
    }

    override func process(ledgerInfo: DyStakingLedger?) {
        self.ledgerInfo = ledgerInfo

        stateMachine?.transit(to: self)
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
                                             ledgerInfo: nil,
                                             nomination: nomination)
        } else {
            newState = PendingValidatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             prefs: nil)
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
                                             ledgerInfo: nil,
                                             prefs: prefs)
        } else {
            newState = PendingNominatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo,
                                             nomination: nil)
        }

        stateMachine.transit(to: newState)
    }
}
