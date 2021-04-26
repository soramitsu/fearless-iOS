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
            StakingBalanceViewModel(
                widgetViewModels: createWidgetViewModels(from: balanceData, locale: locale),
                unbondings: createUnbondingsViewModels(from: balanceData, locale: locale)
            )
        }
    }

    func createWidgetViewModels(
        from balanceData: StakingBalanceData,
        locale: Locale
    ) -> [StakingBalanceWidgetViewModel] {
        let precision = chain.addressType.precision
        var viewModels = [StakingBalanceWidgetViewModel]()

        if let bondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.active,
            precision: precision
        ) {
            let bondedAmountTokenText = tokenAmountText(bondedDecimal, locale: locale)
            let bondedUsdText = priceText(bondedDecimal, priceData: balanceData.priceData, locale: locale)
            let viewModel = StakingBalanceWidgetViewModel(
                title: R.string.localizable.walletBalanceBonded(preferredLanguages: locale.rLanguages),
                tokenAmountText: bondedAmountTokenText,
                usdAmountText: bondedUsdText
            )
            viewModels.append(viewModel)
        }

        if let unbondedDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.unbounding(inEra: balanceData.activeEra),
            precision: precision
        ) {
            let unbondedAmountTokenText = tokenAmountText(unbondedDecimal, locale: locale)
            let unbondedUsdText = priceText(unbondedDecimal, priceData: balanceData.priceData, locale: locale)
            let viewModel = StakingBalanceWidgetViewModel(
                title: R.string.localizable.walletBalanceUnbonding(preferredLanguages: locale.rLanguages),
                tokenAmountText: unbondedAmountTokenText,
                usdAmountText: unbondedUsdText
            )
            viewModels.append(viewModel)
        }

        if let redeemableDecimal = Decimal.fromSubstrateAmount(
            balanceData.stakingLedger.redeemable(inEra: balanceData.activeEra),
            precision: precision
        ) {
            let redeemableAmountTokenText = tokenAmountText(redeemableDecimal, locale: locale)
            let redeemableUsdText = priceText(redeemableDecimal, priceData: balanceData.priceData, locale: locale)
            let viewModel = StakingBalanceWidgetViewModel(
                title: R.string.localizable.walletBalanceRedeemable(preferredLanguages: locale.rLanguages),
                tokenAmountText: redeemableAmountTokenText,
                usdAmountText: redeemableUsdText
            )
            viewModels.append(viewModel)
        }

        return viewModels
    }

    func createUnbondingsViewModels(
        from balanceData: StakingBalanceData,
        locale _: Locale
    ) -> [UnbondingItemViewModel] {
        let precision: Int16 = 0
        return balanceData.stakingLedger.unlocking
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
