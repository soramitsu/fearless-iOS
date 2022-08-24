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

    func replaceBalanceViewModelFactory(balanceViewModelFactory: BalanceViewModelFactoryProtocol?)

    func buildNetworkInfoViewModels(
        networkInfo: StakingPoolNetworkInfo,
        chainAsset: ChainAsset
    ) -> [LocalizableResource<NetworkInfoContentViewModel>]
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
//        if let factory = rewardViewModelFactory {
//            return factory
//        }

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
    func replaceBalanceViewModelFactory(balanceViewModelFactory: BalanceViewModelFactoryProtocol?) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

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

    func buildNetworkInfoViewModels(
        networkInfo: StakingPoolNetworkInfo,
        chainAsset: ChainAsset
    ) -> [LocalizableResource<NetworkInfoContentViewModel>] {
        var viewModels: [LocalizableResource<NetworkInfoContentViewModel>] = []

        if let minJoinBond = networkInfo.minJoinBond,
           let minJoinBondDecimal = Decimal.fromSubstrateAmount(
               minJoinBond,
               precision: Int16(chainAsset.asset.precision)
           ) {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                let minJoinBondValueString = self.balanceViewModelFactory?.amountFromValue(minJoinBondDecimal)
                    .value(for: locale) ?? ""

                return NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainMinCreateTitle(preferredLanguages: locale.rLanguages),
                    value: minJoinBondValueString,
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        if let minCreateBond = networkInfo.minCreateBond,
           let minCreateBondDecimal = Decimal.fromSubstrateAmount(
               minCreateBond,
               precision: Int16(chainAsset.asset.precision)
           ) {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                let minCreateBondValueString = self.balanceViewModelFactory?.amountFromValue(minCreateBondDecimal)
                    .value(for: locale) ?? ""

                return NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainMinCreateTitle(preferredLanguages: locale.rLanguages),
                    value: minCreateBondValueString,
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        if let existingPoolsCount = networkInfo.existingPoolsCount {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainExistingPoolsTitle(preferredLanguages: locale.rLanguages),
                    value: "\(existingPoolsCount)",
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        if let possiblePoolsCount = networkInfo.possiblePoolsCount {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainPossiblePoolsTitle(preferredLanguages: locale.rLanguages),
                    value: "\(possiblePoolsCount)",
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        if let maxMembersInPool = networkInfo.maxMembersInPool {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainMaxMembersInpoolTitle(preferredLanguages: locale.rLanguages),
                    value: "\(maxMembersInPool)",
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        if let maxPoolsMembers = networkInfo.maxPoolsMembers {
            let localizableViewModel = LocalizableResource { locale -> NetworkInfoContentViewModel in
                NetworkInfoContentViewModel(
                    title: R.string.localizable.poolStakingMainMaxPoolMembersTitle(preferredLanguages: locale.rLanguages),
                    value: "\(maxPoolsMembers)",
                    details: nil
                )
            }

            viewModels.append(localizableViewModel)
        }

        return viewModels
    }
}
