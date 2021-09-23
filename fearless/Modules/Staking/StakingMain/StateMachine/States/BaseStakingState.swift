import Foundation
import BigInt

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

    func process(chain: Chain?) {
        if commonData.chain != chain {
            commonData = StakingStateCommonData.empty.byReplacing(chain: chain)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState = InitialStakingState(
                stateMachine: stateMachine,
                commonData: commonData
            )

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

            let newState = InitialStakingState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine.transit(to: newState)
        }
    }

    func process(accountInfo: AccountInfo?) {
        commonData = commonData.byReplacing(accountInfo: accountInfo)

        stateMachine?.transit(to: self)
    }

    func process(price: PriceData?) {
        commonData = commonData.byReplacing(price: price)

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

    func process(rewardEstimationAmount _: Decimal?) {}
    func process(stashItem _: StashItem?) {}
    func process(ledgerInfo _: StakingLedger?) {}
    func process(nomination _: Nomination?) {}
    func process(validatorPrefs _: ValidatorPrefs?) {}
    func process(totalReward _: TotalRewardItem?) {}
    func process(payee _: RewardDestinationArg?) {}

    func process(eraCountdown: EraCountdown) {
        commonData = commonData.byReplacing(eraCountdown: eraCountdown)

        stateMachine?.transit(to: self)
    }

    func process(subqueryRewards: ([SubqueryRewardItemData]?, AnalyticsPeriod)) {
        commonData = commonData.byReplacing(subqueryRewards: subqueryRewards.0, period: subqueryRewards.1)

        stateMachine?.transit(to: self)
    }
}
