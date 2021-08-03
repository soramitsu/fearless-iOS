import Foundation
import BigInt

struct StakingStateCommonData {
    let address: String?
    let chain: Chain?
    let accountInfo: AccountInfo?
    let price: PriceData?
    let calculatorEngine: RewardCalculatorEngineProtocol?
    let eraStakersInfo: EraStakersInfo?
    let minStake: BigUInt?
    let maxNominatorsPerValidator: UInt32?
    let minNominatorBond: BigUInt?
    let counterForNominators: UInt32?
    let maxNominatorsCount: UInt32?
    let eraCountdown: EraCountdown?
}

extension StakingStateCommonData {
    static var empty: StakingStateCommonData {
        StakingStateCommonData(
            address: nil,
            chain: nil,
            accountInfo: nil,
            price: nil,
            calculatorEngine: nil,
            eraStakersInfo: nil,
            minStake: nil,
            maxNominatorsPerValidator: nil,
            minNominatorBond: nil,
            counterForNominators: nil,
            maxNominatorsCount: nil,
            eraCountdown: nil
        )
    }

    func byReplacing(address: String?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(chain: Chain?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(accountInfo: AccountInfo?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(price: PriceData?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(calculatorEngine: RewardCalculatorEngineProtocol?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(eraStakersInfo: EraStakersInfo?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(minStake: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(maxNominatorsPerValidator: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(minNominatorBond: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(counterForNominators: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(maxNominatorsCount: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }

    func byReplacing(eraCountdown: EraCountdown?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chain: chain,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown
        )
    }
}
