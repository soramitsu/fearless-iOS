import Foundation

class BaseStakingState: StakingStateProtocol {
    weak var stateMachine: StakingStateMachineProtocol?

    private(set) var commonData: StakingStateCommonData

    init(stateMachine: StakingStateMachineProtocol?,
         commonData: StakingStateCommonData) {
        self.stateMachine = stateMachine
        self.commonData = commonData
    }

    func accept(visitor: StakingStateVisitorProtocol) {}

    func process(chain: Chain?) {
        if commonData.chain != chain {
            self.commonData = StakingStateCommonData.empty.byReplacing(chain: chain)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState = InitialStakingState(stateMachine: stateMachine,
                                               commonData: commonData)

            stateMachine.transit(to: newState)
        }
    }

    func process(address: String?) {
        if self.commonData.address != address {
            self.commonData = commonData
                .byReplacing(address: address)
                .byReplacing(accountInfo: nil)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState = InitialStakingState(stateMachine: stateMachine,
                                               commonData: commonData)

            stateMachine.transit(to: newState)
        }
    }

    func process(accountInfo: DyAccountInfo?) {
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

    func process(rewardEstimationAmount: Decimal?) {}
    func process(stashItem: StashItem?) {}
    func process(ledgerInfo: DyStakingLedger?) {}
    func process(nomination: Nomination?) {}
    func process(validatorPrefs: ValidatorPrefs?) {}
    func process(totalReward: TotalRewardItem?) {}
    func process(payee: RewardDestinationArg?) {}
}
