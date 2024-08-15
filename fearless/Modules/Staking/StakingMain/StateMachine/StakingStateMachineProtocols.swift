import Foundation
import BigInt
import SSFModels

protocol StakingStateVisitorProtocol {
    func visit(state: InitialRelaychainStakingState)
    func visit(state: NoStashState)
    func visit(state: StashState)
    func visit(state: PendingBondedState)
    func visit(state: BondedState)
    func visit(state: PendingNominatorState)
    func visit(state: NominatorState)
    func visit(state: PendingValidatorState)
    func visit(state: ValidatorState)
    func visit(state: ParachainState)
}

protocol StakingStateProtocol {
    func accept(visitor: StakingStateVisitorProtocol)

    func process(address: String?)
    func process(chainAsset: ChainAsset?)
    func process(accountInfo: AccountInfo?)
    func process(rewardEstimationAmount: Decimal?)
    func process(calculator: RewardCalculatorEngineProtocol?)
    func process(stashItem: StashItem?)
    func process(ledgerInfo: StakingLedger?)
    func process(nomination: Nomination?)
    func process(validatorPrefs: ValidatorPrefs?)
    func process(eraStakersInfo: EraStakersInfo?)
    func process(totalReward: TotalRewardItem?)
    func process(payee: RewardDestinationArg?)
    func process(minStake: BigUInt?)
    func process(maxNominatorsPerValidator: UInt32?)
    func process(minNominatorBond: BigUInt?)
    func process(counterForNominators: UInt32?)
    func process(maxNominatorsCount: UInt32?)
    func process(eraCountdown: EraCountdown)
    func process(subqueryRewards: ([SubqueryRewardItemData]?, AnalyticsPeriod))
    func process(delegationInfos: [ParachainStakingDelegationInfo]?)
    func process(scheduledRequests: [AccountAddress: [ParachainStakingScheduledRequest]]?)
    func process(bottomDelegations: [AccountAddress: ParachainStakingDelegations]?)
    func process(topDelegations: [AccountAddress: ParachainStakingDelegations]?)
    func process(roundInfo: ParachainStakingRoundInfo?)
    func process(currentBlock: UInt32?)
    func process(rewardChainAsset: ChainAsset?)
    func process(rewardAssetPrice: PriceData?)
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
