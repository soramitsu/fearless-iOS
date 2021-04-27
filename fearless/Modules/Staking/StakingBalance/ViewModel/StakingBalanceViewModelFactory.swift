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

            return StakingBalanceViewModel(
                widgetViewModel: widgetViewModel,
                actionsViewModel: createActionsViewModel(redeemableDecimal: redeemableDecimal, locale: locale),
                unbondingViewModel: createUnbondingViewModel(from: balanceData, precision: precision, locale: locale)
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
            balanceData.stakingLedger.unbounding(inEra: balanceData.activeEra),
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
        from balanceData: StakingBalanceData,
        precision: Int16,
        locale: Locale
    ) -> StakingBalanceUnbondingWidgetViewModel {
        StakingBalanceUnbondingWidgetViewModel(
            title: R.string.localizable
                .walletBalanceUnbonding(preferredLanguages: locale.rLanguages),
            emptyListDescription: "Your unbondings will appear here.", // TODO:
            unbondings: createUnbondingsViewModels(from: balanceData, precision: precision, locale: locale)
        )
    }

    func createUnbondingsViewModels(
        from balanceData: StakingBalanceData,
        precision: Int16,
        locale _: Locale
    ) -> [UnbondingItemViewModel] {
        balanceData.stakingLedger.unlocking
            .map { unbondingItem -> UnbondingItemViewModel in
                let tokenAmount = Decimal
                    .fromSubstrateAmount(
                        unbondingItem.value,
                        precision: precision
                    ) ?? .zero
                return UnbondingItemViewModel(
                    addressOrName: "Unbond",
                    daysLeftText: .init(string: "days left"),
                    tokenAmountText: tokenAmount.description,
                    usdAmountText: "10"
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

    private func daysLeftAttributedString(
        activeEra: EraIndex,
        unbondingEra: EraIndex,
        historyDepth: UInt32,
        locale: Locale
    ) -> NSAttributedString {
        let eraDistance = historyDepth - (activeEra - unbondingEra)
        let daysLeft = Int(eraDistance) / chain.erasPerDay
        let daysLeftText = R.string.localizable
            .stakingPayoutsDaysLeft(format: daysLeft, preferredLanguages: locale.rLanguages)

        let attrubutedString = NSAttributedString(
            string: daysLeftText,
            attributes: [.foregroundColor: R.color.colorLightGray()!]
        )
        return attrubutedString
    }
}
