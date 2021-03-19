import Foundation

struct StakingStateCommonData {
    let address: String?
    let chain: Chain?
    let accountInfo: DyAccountInfo?
    let price: PriceData?
    let calculatorEngine: RewardCalculatorEngineProtocol?
    let electionStatus: ElectionStatus?
    let eraStakersInfo: EraStakersInfo?
}

extension StakingStateCommonData {
    static var empty: StakingStateCommonData {
        StakingStateCommonData(address: nil,
                               chain: nil,
                               accountInfo: nil,
                               price: nil,
                               calculatorEngine: nil,
                               electionStatus: nil,
                               eraStakersInfo: nil)
    }

    func byReplacing(address: String?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(chain: Chain?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(accountInfo: DyAccountInfo?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(price: PriceData?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(calculatorEngine: RewardCalculatorEngineProtocol?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(electionStatus: ElectionStatus?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }

    func byReplacing(eraStakersInfo: EraStakersInfo?) -> StakingStateCommonData {
        StakingStateCommonData(address: address,
                               chain: chain,
                               accountInfo: accountInfo,
                               price: price,
                               calculatorEngine: calculatorEngine,
                               electionStatus: electionStatus,
                               eraStakersInfo: eraStakersInfo)
    }
}
