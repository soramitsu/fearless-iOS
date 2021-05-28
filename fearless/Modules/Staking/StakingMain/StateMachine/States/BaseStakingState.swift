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

    func process(electionStatus: ElectionStatus?) {
        commonData = commonData.byReplacing(electionStatus: electionStatus)

        stateMachine?.transit(to: self)
    }

    func process(minimalStake: BigUInt?) {
        commonData = commonData.byReplacing(minimalStake: minimalStake)

        stateMachine?.transit(to: self)
    }

    func process(maxNominatorsPerValidator: UInt32?) {
        commonData = commonData.byReplacing(maxNominatorsPerValidator: maxNominatorsPerValidator)

        stateMachine?.transit(to: self)
    }

    func process(rewardEstimationAmount _: Decimal?) {}
    func process(stashItem _: StashItem?) {}
    func process(ledgerInfo _: StakingLedger?) {}
    func process(nomination _: Nomination?) {}
    func process(validatorPrefs _: ValidatorPrefs?) {}
    func process(totalReward _: TotalRewardItem?) {}
    func process(payee _: RewardDestinationArg?) {}
}
