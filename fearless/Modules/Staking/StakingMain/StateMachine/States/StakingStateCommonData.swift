import Foundation
import BigInt

struct StakingStateCommonData {
    let address: String?
    let chainAsset: ChainAsset?
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
    let subqueryRewards: ([SubqueryRewardItemData]?, AnalyticsPeriod)?
}

extension StakingStateCommonData {
    static var empty: StakingStateCommonData {
        StakingStateCommonData(
            address: nil,
            chainAsset: nil,
            accountInfo: nil,
            price: nil,
            calculatorEngine: nil,
            eraStakersInfo: nil,
            minStake: nil,
            maxNominatorsPerValidator: nil,
            minNominatorBond: nil,
            counterForNominators: nil,
            maxNominatorsCount: nil,
            eraCountdown: nil,
            subqueryRewards: nil
        )
    }

    func byReplacing(address: String?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(accountInfo: AccountInfo?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(price: PriceData?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(calculatorEngine: RewardCalculatorEngineProtocol?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(eraStakersInfo: EraStakersInfo?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(minStake: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(maxNominatorsPerValidator: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(minNominatorBond: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(counterForNominators: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(maxNominatorsCount: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(eraCountdown: EraCountdown?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: subqueryRewards
        )
    }

    func byReplacing(subqueryRewards: [SubqueryRewardItemData]?, period: AnalyticsPeriod) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountInfo: accountInfo,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            eraCountdown: eraCountdown,
            subqueryRewards: (subqueryRewards, period)
        )
    }
}
