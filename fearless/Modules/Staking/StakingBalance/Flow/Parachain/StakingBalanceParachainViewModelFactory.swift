import Foundation
import SoraFoundation
import BigInt

final class StakingBalanceParachainViewModelFactory: StakingBalanceViewModelFactoryProtocol {
    private let asset: AssetModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let timeFormatter: TimeFormatterProtocol

    init(
        asset: AssetModel,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        timeFormatter: TimeFormatterProtocol
    ) {
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.timeFormatter = timeFormatter
    }

    func buildViewModel(viewModelState: StakingBalanceViewModelState, priceData: PriceData?) -> LocalizableResource<StakingBalanceViewModel>? {
        guard let viewModelState = viewModelState as? StakingBalanceParachainViewModelState else {
            return nil
        }

        return LocalizableResource { [unowned self] locale in
            let precision = Int16(self.asset.precision)
            let redeemableDecimal = Decimal.fromSubstrateAmount(
                BigUInt.zero,
                precision: precision
            ) ?? 0.0

            let widgetViewModel = self.createWidgetViewModel(
                from: viewModelState,
                precision: precision,
                redeemableDecimal: redeemableDecimal,
                locale: locale,
                priceData: priceData
            )

            let unbondingViewModel = self.createUnbondingViewModel(
                viewModelState: viewModelState,
                priceData: priceData,
                precision: precision,
                locale: locale
            )

            return StakingBalanceViewModel(
                widgetViewModel: widgetViewModel,
                actionsViewModel: self.createActionsViewModel(redeemableDecimal: redeemableDecimal, locale: locale),
                unbondingViewModel: unbondingViewModel
            )
        }
    }

    func createWidgetViewModel(
        from viewModelState: StakingBalanceParachainViewModelState,
        precision: Int16,
        redeemableDecimal: Decimal,
        locale: Locale,
        priceData: PriceData?
    ) -> StakingBalanceWidgetViewModel {
        let bondedDecimal = Decimal.fromSubstrateAmount(
            viewModelState.delegation.amount,
            precision: precision
        ) ?? 0.0
        let bondedViewModel = createWidgetItemViewModel(
            amount: bondedDecimal,
            title: R.string.localizable.walletBalanceBonded(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        let unbondedDecimal = Decimal.fromSubstrateAmount(
            BigUInt.zero,
            precision: precision
        ) ?? 0.0
        let unbondedViewModel = createWidgetItemViewModel(
            amount: unbondedDecimal,
            title: R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        let redeemableViewModel = createWidgetItemViewModel(
            amount: redeemableDecimal,
            title: R.string.localizable.walletBalanceRedeemable(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        return StakingBalanceWidgetViewModel(
            title: R.string.localizable.commonBalance(preferredLanguages: locale.rLanguages),
            itemViewModels: [bondedViewModel, unbondedViewModel, redeemableViewModel]
        )
    }

    func createWidgetItemViewModel(
        amount: Decimal,
        title: String,
        priceData: PriceData?,
        locale: Locale
    ) -> StakingBalanceWidgetItemViewModel {
        StakingBalanceWidgetItemViewModel(
            title: title,
            tokenAmountText: tokenAmountText(amount, locale: locale),
            usdAmountText: priceText(amount, priceData: priceData, locale: locale)
        )
    }

    func createActionsViewModel(
        redeemableDecimal: Decimal,
        locale: Locale
    ) -> StakingBalanceActionsWidgetViewModel {
        StakingBalanceActionsWidgetViewModel(
            bondTitle: StakingBalanceAction.bondMore.title(for: locale),
            unbondTitle: StakingBalanceAction.unbond.title(for: locale),
            redeemTitle: StakingBalanceAction.redeem.title(for: locale),
            redeemActionIsAvailable: redeemableDecimal > 0
        )
    }

    func createUnbondingViewModel(
        viewModelState: StakingBalanceParachainViewModelState,
        priceData: PriceData?,
        precision: Int16,
        locale: Locale
    ) -> StakingBalanceUnbondingWidgetViewModel {
        let viewModels = createUnbondingsViewModels(
            from: viewModelState,
            priceData: priceData,
            precision: precision,
            locale: locale
        )
        return StakingBalanceUnbondingWidgetViewModel(
            title: R.string.localizable
                .walletBalanceUnbonding_v190(preferredLanguages: locale.rLanguages),
            emptyListDescription: R.string.localizable
                .stakingUnbondingEmptyList_v190(preferredLanguages: locale.rLanguages),
            unbondings: viewModels
        )
    }

    func createUnbondingsViewModels(
        from _: StakingBalanceParachainViewModelState,
        priceData _: PriceData?,
        precision _: Int16,
        locale _: Locale
    ) -> [UnbondingItemViewModel] {
        []
//        balanceData.stakingLedger
//            .unbondings(inEra: balanceData.activeEra)
//            .sorted(by: { $0.era < $1.era })
//            .map { unbondingItem -> UnbondingItemViewModel in
//                let unbondingAmountDecimal = Decimal
//                    .fromSubstrateAmount(
//                        unbondingItem.value,
//                        precision: precision
//                    ) ?? .zero
//                let tokenAmount = tokenAmountText(unbondingAmountDecimal, locale: locale)
//                let usdAmount = priceText(unbondingAmountDecimal, priceData: priceData, locale: locale)
//                let timeLeft = timeLeftAttributedString(
//                    unbondingEra: unbondingItem.era,
//                    eraCountdown: balanceData.eraCountdown,
//                    locale: locale
//                )
//
//                return UnbondingItemViewModel(
//                    addressOrName: R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages),
//                    daysLeftText: timeLeft,
//                    tokenAmountText: tokenAmount,
//                    usdAmountText: usdAmount
//                )
//            }
    }

    private func tokenAmountText(_ value: Decimal, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?, locale: Locale) -> String? {
        guard let priceData = priceData else {
            return nil
        }

        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func timeLeftAttributedString(
        unbondingEra: EraIndex,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> NSAttributedString {
        guard let eraCountdown = eraCountdown else { return .init(string: "") }

        let eraCompletionTime = eraCountdown.timeIntervalTillStart(targetEra: unbondingEra)
        let daysLeft = eraCompletionTime.daysFromSeconds

        let timeLeftText: String = {
            if daysLeft == 0 {
                return (try? timeFormatter.string(from: eraCompletionTime)) ?? ""
            } else {
                return R.string.localizable
                    .commonDaysLeftFormat(format: daysLeft, preferredLanguages: locale.rLanguages)
            }
        }()

        let attrubutedString = NSAttributedString(
            string: timeLeftText,
            attributes: [.foregroundColor: R.color.colorLightGray()!]
        )
        return attrubutedString
    }
}
