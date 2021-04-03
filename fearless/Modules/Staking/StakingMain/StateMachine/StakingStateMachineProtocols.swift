import Foundation

protocol StakingStateVisitorProtocol {
    func visit(state: InitialStakingState)
    func visit(state: NoStashState)
    func visit(state: StashState)
    func visit(state: PendingBondedState)
    func visit(state: BondedState)
    func visit(state: PendingNominatorState)
    func visit(state: NominatorState)
    func visit(state: PendingValidatorState)
    func visit(state: ValidatorState)
}

protocol StakingStateProtocol {
    func accept(visitor: StakingStateVisitorProtocol)

    func process(address: String?)
    func process(chain: Chain?)
    func process(accountInfo: DyAccountInfo?)
    func process(price: PriceData?)
    func process(rewardEstimationAmount: Decimal?)
    func process(calculator: RewardCalculatorEngineProtocol?)
    func process(stashItem: StashItem?)
    func process(ledgerInfo: DyStakingLedger?)
    func process(nomination: Nomination?)
    func process(validatorPrefs: ValidatorPrefs?)
    func process(electionStatus: ElectionStatus?)
    func process(eraStakersInfo: EraStakersInfo?)
    func process(totalReward: TotalRewardItem?)
    func process(payee: RewardDestinationArg?)
}

protocol StakingStateMachineProtocol: AnyObject {
    var state: StakingStateProtocol { get }

    func transit(to state: StakingStateProtocol)
}

extension StakingStateMachineProtocol {
    func viewState<S: StakingStateProtocol, V>(using closure: (S) -> V?) -> V? {
        if let concreteState = state as? S {
            return closure(concreteState)
        } else {
            return nil
        }
    }
}

protocol StakingStateMachineDelegate: AnyObject {
    func stateMachineDidChangeState(_ stateMachine: StakingStateMachineProtocol)
}
