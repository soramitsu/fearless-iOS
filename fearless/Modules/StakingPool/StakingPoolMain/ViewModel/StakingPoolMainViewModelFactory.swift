import Foundation
import SoraFoundation
import BigInt
import SSFUtils

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

    // swiftlint:disable function_parameter_count
    func buildNominatorStateViewModel(
        stakeInfo: StakingPoolMember,
        priceData: PriceData?,
        chainAsset: ChainAsset,
        era: EraIndex?,
        poolInfo: StakingPool,
        nomination: Nomination?,
        pendingRewards: BigUInt
    ) -> LocalizableResource<NominationViewModelProtocol>?
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
            accountInfo?.data.stakingAvailable,
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
                    title: R.string.localizable.poolStakingMainMinJoinTitle(preferredLanguages: locale.rLanguages),
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

    func buildNominatorStateViewModel(
        stakeInfo: StakingPoolMember,
        priceData: PriceData?,
        chainAsset: ChainAsset,
        era: EraIndex?,
        poolInfo: StakingPool,
        nomination: Nomination?,
        pendingRewards: BigUInt
    ) -> LocalizableResource<NominationViewModelProtocol>? {
        var status: NominationViewStatus = .undefined
        switch poolInfo.info.state {
        case .open:
            guard let era = era else {
                break
            }

            if nomination?.targets.isNotEmpty == true {
                status = .active(era: era)
            } else {
                status = .validatorsNotSelected
            }
        case .blocked, .destroying:
            guard let era = era else {
                break
            }

            status = .inactive(era: era)
        }

        let precision = Int16(chainAsset.asset.precision)
        let totalStakeAmount = Decimal.fromSubstrateAmount(
            stakeInfo.points,
            precision: precision
        ) ?? 0.0

        var redeemableViewModel: StakingUnitInfoViewModel?
        var unstakingViewModel: StakingUnitInfoViewModel?

        let pendingReward = Decimal.fromSubstrateAmount(pendingRewards, precision: Int16(chainAsset.asset.precision)) ?? Decimal.zero

        guard let totalStake = balanceViewModelFactory?.balanceFromPrice(totalStakeAmount, priceData: priceData),
              let totalReward = balanceViewModelFactory?.balanceFromPrice(pendingReward, priceData: priceData)
        else {
            return nil
        }

        return LocalizableResource { [weak self] locale in
            if let era = era {
                let redeemableAmount = Decimal.fromSubstrateAmount(
                    stakeInfo.redeemable(inEra: era),
                    precision: Int16(chainAsset.asset.precision)
                ) ?? 0
                let redeemable = self?.balanceViewModelFactory?.balanceFromPrice(
                    redeemableAmount,
                    priceData: priceData
                )
                redeemableViewModel = StakingUnitInfoViewModel(
                    value: redeemable?.value(for: locale).amount,
                    subtitle: redeemable?.value(for: locale).price
                )

                let unstakingAmount = Decimal.fromSubstrateAmount(
                    stakeInfo.unbonding(inEra: era),
                    precision: Int16(chainAsset.asset.precision)
                ) ?? 0
                let unstaking = self?.balanceViewModelFactory?.balanceFromPrice(unstakingAmount, priceData: priceData)
                unstakingViewModel = StakingUnitInfoViewModel(
                    value: unstaking?.value(for: locale).amount,
                    subtitle: unstaking?.value(for: locale).price
                )
            }

            return NominationViewModel(
                totalStakedAmount: totalStake.value(for: locale).amount,
                totalStakedPrice: totalStake.value(for: locale).price ?? "",
                totalRewardAmount: totalReward.value(for: locale).amount,
                totalRewardPrice: totalReward.value(for: locale).price ?? "",
                status: status,
                hasPrice: priceData != nil,
                redeemableViewModel: redeemableViewModel,
                unstakingViewModel: unstakingViewModel,
                rewardViewTitle: R.string.localizable.poolClaimableTitle(
                    preferredLanguages: locale.rLanguages
                )
            )
        }
    }
}
