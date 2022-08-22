import Foundation
import SoraFoundation
import BigInt

protocol StakingPoolMainViewModelFactoryProtocol {
    func createEstimationViewModel(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        amount: Decimal?,
        priceData: PriceData?,
        calculatorEngine: RewardCalculatorEngineProtocol?
    ) -> StakingEstimationViewModel
}

final class StakingPoolMainViewModelFactory {
    private var wallet: MetaAccountModel
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    var balanceViewModelFactory: BalanceViewModelFactoryProtocol?

    init(
        wallet: MetaAccountModel
    ) {
        self.wallet = wallet
    }

    private func convertAmount(
        _ amount: BigUInt?,
        for chainAsset: ChainAsset,
        defaultValue: Decimal
    ) -> Decimal {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) ?? defaultValue
        } else {
            return defaultValue
        }
    }

    private func getRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol {
        if let factory = rewardViewModelFactory {
            return factory
        }

        let factory = RewardViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        rewardViewModelFactory = factory

        return factory
    }

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory {
            return factory
        }

        let factory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        balanceViewModelFactory = factory

        return factory
    }

    private func createPeriodReward(
        for chainAsset: ChainAsset,
        amount: Decimal?,
        priceData: PriceData?,
        calculatorEngine: RewardCalculatorEngineProtocol?
    ) -> LocalizableResource<PeriodRewardViewModel>? {
        guard let calculator = calculatorEngine else {
            return nil
        }

        let rewardViewModelFactory = getRewardViewModelFactory(for: chainAsset)

        let monthlyReturn = calculator.calculatorReturn(isCompound: true, period: .month)

        let yearlyReturn = calculator.calculatorReturn(isCompound: true, period: .year)

        let monthlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: (amount ?? 0.0) * monthlyReturn,
            targetReturn: monthlyReturn,
            priceData: priceData
        )

        let yearlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: (amount ?? 0.0) * yearlyReturn,
            targetReturn: yearlyReturn,
            priceData: priceData
        )

        return LocalizableResource { locale in
            PeriodRewardViewModel(
                monthlyReward: monthlyViewModel.value(for: locale),
                yearlyReward: yearlyViewModel.value(for: locale)
            )
        }
    }
}

extension StakingPoolMainViewModelFactory: StakingPoolMainViewModelFactoryProtocol {
    func createEstimationViewModel(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        amount: Decimal?,
        priceData: PriceData?,
        calculatorEngine: RewardCalculatorEngineProtocol?
    )
        -> StakingEstimationViewModel {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let balance = convertAmount(
            accountInfo?.data.available,
            for: chainAsset,
            defaultValue: 0.0
        )

        let balanceViewModel = balanceViewModelFactory
            .createAssetBalanceViewModel(
                amount ?? 0.0,
                balance: balance,
                priceData: priceData
            )

        let reward: LocalizableResource<PeriodRewardViewModel>? = createPeriodReward(
            for: chainAsset,
            amount: amount,
            priceData: priceData,
            calculatorEngine: calculatorEngine
        )

        return StakingEstimationViewModel(
            assetBalance: balanceViewModel,
            rewardViewModel: reward,
            assetInfo: chainAsset.assetDisplayInfo,
            inputLimit: StakingConstants.maxAmount,
            amount: amount
        )
    }
}
