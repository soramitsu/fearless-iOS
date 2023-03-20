import Foundation
import SoraFoundation

final class StakingBalanceRelaychainViewModelFactory: StakingBalanceViewModelFactoryProtocol {
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
        guard let viewModelState = viewModelState as? StakingBalanceRelaychainViewModelState,
              let balanceData = viewModelState.stakingBalanceData else {
            return nil
        }

        return LocalizableResource { [unowned self] locale in
            let precision = Int16(self.asset.precision)
            let redeemableDecimal = Decimal.fromSubstrateAmount(
                balanceData.stakingLedger.redeemable(inEra: balanceData.activeEra),
                precision: precision
            ) ?? 0.0
            let bondedDecimal = Decimal.fromSubstrateAmount(
                balanceData.stakingLedger.active,
                precision: precision
            ) ?? 0.0

            let widgetViewModel = self.createWidgetViewModel(
                from: balanceData,
                precision: precision,
                redeemableDecimal: redeemableDecimal,
                locale: locale,
                priceData: priceData
            )

            let unbondingViewModel = self.createUnbondingViewModel(
                balanceData: balanceData,
                priceData: priceData,
                precision: precision,
                locale: locale
            )

            return StakingBalanceViewModel(
                title: R.string.localizable.stakingBalanceTitle(preferredLanguages: locale.rLanguages),
                widgetViewModel: widgetViewModel,
                actionsViewModel: self.createActionsViewModel(redeemableDecimal: redeemableDecimal, bondedDecimal: bondedDecimal, locale: locale),
                unbondingViewModel: unbondingViewModel
            )
        }
    }

    func createWidgetViewModel(
        from balanceData: StakingBalanceData,
        precision: Int16,
        redeemableDecimal: Decimal,
        locale: Locale,
        priceData: PriceData?
    ) -> StakingBalanceWidgetViewModel {
        let bondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.active,
            precision: precision
        ) ?? 0.0
        let bondedViewModel = createWidgetItemViewModel(
            amount: bondedDecimal,
            title: R.string.localizable.walletBalanceBonded(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        let unbondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.unbonding(inEra: balanceData.activeEra),
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
        bondedDecimal: Decimal,
        locale: Locale
    ) -> StakingBalanceActionsWidgetViewModel {
        StakingBalanceActionsWidgetViewModel(
            bondTitle: StakingBalanceAction.bondMore.title(for: locale),
            unbondTitle: StakingBalanceAction.unbond.title(for: locale),
            redeemTitle: StakingBalanceAction.redeem.title(for: locale),
            redeemIcon: R.image.iconRedeem(),
            redeemActionIsAvailable: redeemableDecimal > 0,
            stakeMoreActionAvailable: true,
            stakeLessActionAvailable: redeemableDecimal != bondedDecimal
        )
    }

    func createUnbondingViewModel(
        balanceData: StakingBalanceData,
        priceData: PriceData?,
        precision: Int16,
        locale: Locale
    ) -> StakingBalanceUnbondingWidgetViewModel {
        let viewModels = createUnbondingsViewModels(
            from: balanceData,
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
        from balanceData: StakingBalanceData,
        priceData: PriceData?,
        precision: Int16,
        locale: Locale
    ) -> [UnbondingItemViewModel] {
        balanceData.stakingLedger
            .unbondings(inEra: balanceData.activeEra)
            .sorted(by: { $0.era < $1.era })
            .map { unbondingItem -> UnbondingItemViewModel in
                let unbondingAmountDecimal = Decimal
                    .fromSubstrateAmount(
                        unbondingItem.value,
                        precision: precision
                    ) ?? .zero
                let tokenAmount = tokenAmountText(unbondingAmountDecimal, locale: locale)
                let usdAmount = priceText(unbondingAmountDecimal, priceData: priceData, locale: locale)

                return UnbondingItemViewModel(
                    addressOrName: R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages),
                    daysLeftText: NSAttributedString(),
                    tokenAmountText: tokenAmount,
                    usdAmountText: usdAmount,
                    timeInterval: timeleft(unbondingEra: unbondingItem.era, eraCountdown: balanceData.eraCountdown),
                    locale: locale
                )
            }
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

    private func timeleft(unbondingEra: EraIndex, eraCountdown: EraCountdown?) -> TimeInterval {
        guard let eraCountdown = eraCountdown else { return 0 }

        return eraCountdown.timeIntervalTillStart(targetEra: unbondingEra)
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
