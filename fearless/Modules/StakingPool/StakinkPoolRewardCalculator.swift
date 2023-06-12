import Foundation
import Web3
import SSFModels

struct PoolRewardCalculatorResult {
    let totalRewardsDecimal: Decimal
    let totalRewards: BalanceViewModel
    let totalStakeDecimal: Decimal
    let totalStake: BalanceViewModel
}

// swiftlint:disable function_parameter_count function_body_length
protocol StakinkPoolRewardCalculatorProtocol {
    func calculate(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        poolInfo: StakingPool,
        poolAccountInfo: AccountInfo,
        poolRewards: StakingPoolRewards,
        stakeInfo: StakingPoolMember,
        existentialDeposit: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> PoolRewardCalculatorResult
}

final class StakinkPoolRewardCalculator: StakinkPoolRewardCalculatorProtocol {
    func calculate(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        poolInfo: StakingPool,
        poolAccountInfo: AccountInfo,
        poolRewards: StakingPoolRewards,
        stakeInfo: StakingPoolMember,
        existentialDeposit: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> PoolRewardCalculatorResult {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        let precision = Int16(chainAsset.asset.precision)
        let totalStakeAmount = Decimal.fromSubstrateAmount(
            stakeInfo.points,
            precision: precision
        ) ?? 0.0

        let poolStakeAmount = Decimal.fromSubstrateAmount(
            poolInfo.info.points,
            precision: precision
        ) ?? 0.0

        let existentialDepositDecimal = Decimal.fromSubstrateAmount(
            existentialDeposit,
            precision: precision
        ) ?? 0.0

        let balanceDecimal = (Decimal.fromSubstrateAmount(
            poolAccountInfo.data.free,
            precision: precision
        ) ?? 0.0) - existentialDepositDecimal

        let totalRewardsClaimed = Decimal.fromSubstrateAmount(
            poolRewards.totalRewardsClaimed,
            precision: precision
        ) ?? 0.0

        let lastRecordedRewardCounter = Decimal.fromSubstrateAmount(
            poolRewards.lastRecordedRewardCounter,
            precision: precision
        ) ?? 0.0

        let lastRecordedTotalPayouts = Decimal.fromSubstrateAmount(
            poolRewards.lastRecordedTotalPayouts,
            precision: precision
        ) ?? 0.0

        let ownLastRecordedRewardCounter = Decimal.fromSubstrateAmount(
            stakeInfo.lastRecordedRewardCounter,
            precision: precision
        ) ?? 0.0

        let payoutSinceLastRecord = balanceDecimal
            + totalRewardsClaimed
            - lastRecordedTotalPayouts

        let rewardCounterBase: Decimal = pow(10, 18)
        let currentRewardCounter = payoutSinceLastRecord
            * rewardCounterBase
            / poolStakeAmount
            + lastRecordedRewardCounter

        let pendingReward = (currentRewardCounter - ownLastRecordedRewardCounter)
            * totalStakeAmount / rewardCounterBase

        let totalReward = balanceViewModelFactory.balanceFromPrice(
            pendingReward,
            priceData: priceData,
            usageCase: .listCrypto
        )

        let totalStake = balanceViewModelFactory.balanceFromPrice(
            totalStakeAmount,
            priceData: priceData,
            usageCase: .listCrypto
        )

        let totalRewardViewModel = BalanceViewModel(
            amount: totalReward.value(for: locale).amount,
            price: totalReward.value(for: locale).price
        )

        let totalStakeViewModel = BalanceViewModel(
            amount: totalStake.value(for: locale).amount,
            price: totalStake.value(for: locale).price
        )

        return PoolRewardCalculatorResult(
            totalRewardsDecimal: pendingReward,
            totalRewards: totalRewardViewModel,
            totalStakeDecimal: totalStakeAmount,
            totalStake: totalStakeViewModel
        )
    }
}
