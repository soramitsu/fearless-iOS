import Foundation
import BigInt
import SSFModels

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
    let rewardChainAsset: ChainAsset?
    let rewardAssetPrice: PriceData?
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
            subqueryRewards: nil,
            rewardChainAsset: nil,
            rewardAssetPrice: nil
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
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
            subqueryRewards: (subqueryRewards, period),
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
        )
    }

    func byReplacing(rewardChainAsset: ChainAsset?) -> StakingStateCommonData {
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
        )
    }

    func byReplacing(rewardAssetPrice: PriceData?) -> StakingStateCommonData {
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
            subqueryRewards: subqueryRewards,
            rewardChainAsset: rewardChainAsset,
            rewardAssetPrice: rewardAssetPrice
        )
    }
}
