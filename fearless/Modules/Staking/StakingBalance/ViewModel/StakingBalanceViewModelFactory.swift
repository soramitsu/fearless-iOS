import Foundation
import SoraFoundation

struct StakingBalanceViewModelFactory: StakingBalanceViewModelFactoryProtocol {
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViewModel(from balanceData: StakingBalanceData) -> LocalizableResource<StakingBalanceViewModel> {
        LocalizableResource { locale in
            let precision = chain.addressType.precision
            let redeemableDecimal = Decimal.fromSubstrateAmount(
                balanceData.stakingLedger.redeemable(inEra: balanceData.activeEra),
                precision: precision
            ) ?? 0.0

            let widgetViewModel = createWidgetViewModel(
                from: balanceData,
                precision: precision,
                redeemableDecimal: redeemableDecimal,
                locale: locale
            )

            let unbondingViewModel = createUnbondingViewModel(
                balanceData: balanceData,
                precision: precision,
                locale: locale
            )

            return StakingBalanceViewModel(
                widgetViewModel: widgetViewModel,
                actionsViewModel: createActionsViewModel(redeemableDecimal: redeemableDecimal, locale: locale),
                unbondingViewModel: unbondingViewModel
            )
        }
    }

    func createWidgetViewModel(
        from balanceData: StakingBalanceData,
        precision: Int16,
        redeemableDecimal: Decimal,
        locale: Locale
    ) -> StakingBalanceWidgetViewModel {
        let bondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.active,
            precision: precision
        ) ?? 0.0
        let bondedViewModel = createWidgetItemViewModel(
            amount: bondedDecimal,
            title: R.string.localizable.walletBalanceBonded(preferredLanguages: locale.rLanguages),
            priceData: balanceData.priceData,
            locale: locale
        )

        let unbondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.unbonding(inEra: balanceData.activeEra),
            precision: precision
        ) ?? 0.0
        let unbondedViewModel = createWidgetItemViewModel(
            amount: unbondedDecimal,
            title: R.string.localizable.walletBalanceUnbonding(preferredLanguages: locale.rLanguages),
            priceData: balanceData.priceData,
            locale: locale
        )

        let redeemableViewModel = createWidgetItemViewModel(
            amount: redeemableDecimal,
            title: R.string.localizable.walletBalanceRedeemable(preferredLanguages: locale.rLanguages),
            priceData: balanceData.priceData,
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
        balanceData: StakingBalanceData,
        precision: Int16,
        locale: Locale
    ) -> StakingBalanceUnbondingWidgetViewModel {
        let viewModels = createUnbondingsViewModels(
            from: balanceData,
            precision: precision,
            locale: locale
        )
        return StakingBalanceUnbondingWidgetViewModel(
            title: R.string.localizable
                .walletBalanceUnbonding(preferredLanguages: locale.rLanguages),
            emptyListDescription: R.string.localizable
                .stakingUnbondingEmptyList(preferredLanguages: locale.rLanguages),
            unbondings: viewModels
        )
    }

    func createUnbondingsViewModels(
        from balanceData: StakingBalanceData,
        precision _: Int16,
        locale: Locale
    ) -> [UnbondingItemViewModel] {
        (0 ..< 4)
            .map { _ in
                let tokenAmount = "KSM"
                let usdAmount = "$"
                let daysLeft = timeLeftAttributedString(
                    activeEra: 1000,
                    unbondingEra: 1000,
                    eraCompletionTimeInSeconds: balanceData.eraCompletionTimeInSeconds,
                    locale: locale
                )

                return UnbondingItemViewModel(
                    addressOrName: R.string.localizable.stakingUnbond(preferredLanguages: locale.rLanguages),
                    daysLeftText: daysLeft,
                    tokenAmountText: tokenAmount,
                    usdAmountText: usdAmount
                )
            }
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
//                let usdAmount = priceText(unbondingAmountDecimal, priceData: balanceData.priceData, locale: locale)
//                let daysLeft = daysLeftAttributedString(
//                    activeEra: balanceData.activeEra,
//                    unbondingEra: unbondingItem.era,
//                    eraCompletionTimeInSeconds: balanceData.eraCompletionTimeInSeconds,
//                    locale: locale
//                )
//
//                return UnbondingItemViewModel(
//                    addressOrName: R.string.localizable.stakingUnbond(preferredLanguages: locale.rLanguages),
//                    daysLeftText: daysLeft,
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
        activeEra: EraIndex,
        unbondingEra: EraIndex,
        eraCompletionTimeInSeconds: TimeInterval?,
        locale: Locale
    ) -> NSAttributedString {
        let eraDistance = unbondingEra - activeEra
        let daysLeft = Int(eraDistance) / chain.erasPerDay
        let timeLeftText: String = {
            if daysLeft == 0, let eraCompletionTimeInSeconds = eraCompletionTimeInSeconds {
                return timeString(time: eraCompletionTimeInSeconds)
            }
            return R.string.localizable
                .stakingPayoutsDaysLeft(format: daysLeft, preferredLanguages: locale.rLanguages)
        }()

        let attrubutedString = NSAttributedString(
            string: timeLeftText,
            attributes: [.foregroundColor: R.color.colorLightGray()!]
        )
        return attrubutedString
    }

    // TODO: refactor
    func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
