import Foundation
import BigInt
import SSFModels

class BaseStakingState: StakingStateProtocol {
    weak var stateMachine: StakingStateMachineProtocol?

    private(set) var commonData: StakingStateCommonData

    init(
        stateMachine: StakingStateMachineProtocol?,
        commonData: StakingStateCommonData
    ) {
        self.stateMachine = stateMachine
        self.commonData = commonData
    }

    func accept(visitor _: StakingStateVisitorProtocol) {}

    func process(chainAsset: ChainAsset?) {
        if commonData.chainAsset != chainAsset {
            commonData = StakingStateCommonData.empty.byReplacing(chainAsset: chainAsset)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState: BaseStakingState
            switch chainAsset?.stakingType {
            case .relaychain, .sora, .ternoa:
                newState = InitialRelaychainStakingState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )
            case .parachain:
                newState = ParachainState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )
            case .none:
                return
            }

            stateMachine.transit(to: newState)
        }
    }

    func process(address: String?) {
        if commonData.address != address {
            commonData = commonData
                .byReplacing(address: address)
                .byReplacing(accountInfo: nil)
                .byReplacing(subqueryRewards: nil, period: .week)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState: BaseStakingState
            if case .parachain = commonData.chainAsset?.stakingType {
                newState = ParachainState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )
            } else {
                newState = InitialRelaychainStakingState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )
            }

            stateMachine.transit(to: newState)
        }
    }

    func process(accountInfo: AccountInfo?) {
        commonData = commonData.byReplacing(accountInfo: accountInfo)

        stateMachine?.transit(to: self)
    }

    func process(calculator: RewardCalculatorEngineProtocol?) {
        commonData = commonData.byReplacing(calculatorEngine: calculator)

        stateMachine?.transit(to: self)
    }

    func process(eraStakersInfo: EraStakersInfo?) {
        commonData = commonData.byReplacing(eraStakersInfo: eraStakersInfo)

        stateMachine?.transit(to: self)
    }

    func process(minStake: BigUInt?) {
        commonData = commonData.byReplacing(minStake: minStake)

        stateMachine?.transit(to: self)
    }

    func process(maxNominatorsPerValidator: UInt32?) {
        commonData = commonData.byReplacing(maxNominatorsPerValidator: maxNominatorsPerValidator)

        stateMachine?.transit(to: self)
    }

    func process(minNominatorBond: BigUInt?) {
        commonData = commonData.byReplacing(minNominatorBond: minNominatorBond)

        stateMachine?.transit(to: self)
    }

    func process(counterForNominators: UInt32?) {
        commonData = commonData.byReplacing(counterForNominators: counterForNominators)

        stateMachine?.transit(to: self)
    }

    func process(maxNominatorsCount: UInt32?) {
        commonData = commonData.byReplacing(maxNominatorsCount: maxNominatorsCount)

        stateMachine?.transit(to: self)
    }

    func process(rewardChainAsset: ChainAsset?) {
        commonData = commonData.byReplacing(rewardChainAsset: rewardChainAsset)

        stateMachine?.transit(to: self)
    }

    func process(rewardAssetPrice: PriceData?) {
        commonData = commonData.byReplacing(rewardAssetPrice: rewardAssetPrice)

        stateMachine?.transit(to: self)
    }

    func process(rewardEstimationAmount _: Decimal?) {}
    func process(stashItem _: StashItem?) {}
    func process(ledgerInfo _: StakingLedger?) {}
    func process(nomination _: Nomination?) {}
    func process(validatorPrefs _: ValidatorPrefs?) {}
    func process(totalReward _: TotalRewardItem?) {}
    func process(payee _: RewardDestinationArg?) {}
    func process(delegationInfos _: [ParachainStakingDelegationInfo]?) {}
    func process(topDelegations _: [AccountAddress: ParachainStakingDelegations]?) {}
    func process(bottomDelegations _: [AccountAddress: ParachainStakingDelegations]?) {}
    func process(scheduledRequests _: [AccountAddress: [ParachainStakingScheduledRequest]]?) {}
    func process(roundInfo _: ParachainStakingRoundInfo?) {}
    func process(currentBlock _: UInt32?) {}

    func process(eraCountdown: EraCountdown) {
        commonData = commonData.byReplacing(eraCountdown: eraCountdown)

        stateMachine?.transit(to: self)
    }

    func process(subqueryRewards: ([SubqueryRewardItemData]?, AnalyticsPeriod)) {
        commonData = commonData.byReplacing(subqueryRewards: subqueryRewards.0, period: subqueryRewards.1)

        stateMachine?.transit(to: self)
    }
}
