import Foundation
import SoraFoundation
import SSFModels
import SoraKeystore

protocol WalletsManagmentViewModelFactoryProtocol {
    func buildViewModel(
        viewType: WalletsManagmentType,
        from wallets: [ManagedMetaAccountModel],
        balances: [MetaAccountId: WalletBalanceInfo],
        locale: Locale
    ) -> [WalletsManagmentCellViewModel]
}

final class WalletsManagmentViewModelFactory: WalletsManagmentViewModelFactoryProtocol {
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let accountScoreFetcher: AccountStatisticsFetching

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        accountScoreFetcher: AccountStatisticsFetching
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.accountScoreFetcher = accountScoreFetcher
    }

    func buildViewModel(
        viewType: WalletsManagmentType,
        from wallets: [ManagedMetaAccountModel],
        balances: [MetaAccountId: WalletBalanceInfo],
        locale: Locale
    ) -> [WalletsManagmentCellViewModel] {
        wallets.compactMap { managedMetaAccount -> WalletsManagmentCellViewModel? in
            let key = managedMetaAccount.info.metaId

            let isSelected: Bool
            switch viewType {
            case .wallets:
                isSelected = managedMetaAccount.isSelected
            case let .selectYourWallet(selectedWalletId):
                isSelected = selectedWalletId == nil ? false : managedMetaAccount.info.metaId == selectedWalletId
            }

            let address = managedMetaAccount.info.ethereumAddress?.toHex(includePrefix: true)
            let accountScoreViewModel = AccountScoreViewModel(
                fetcher: accountScoreFetcher,
                address: address,
                chain: nil,
                settings: SettingsManager.shared,
                eventCenter: EventCenter.shared,
                logger: Logger.shared
            )

            guard let walletBalance = balances[key] else {
                return WalletsManagmentCellViewModel(
                    isSelected: isSelected,
                    walletName: managedMetaAccount.info.name,
                    fiatBalance: nil,
                    dayChange: nil,
                    accountScoreViewModel: accountScoreViewModel
                )
            }

            let balanceTokenFormatterValue = tokenFormatter(
                for: walletBalance.currency,
                locale: locale
            )

            guard
                walletBalance.totalFiatValue != .zero,
                let totalFiatValue = balanceTokenFormatterValue.stringFromDecimal(walletBalance.totalFiatValue)
            else {
                let fiatBalance = balanceTokenFormatterValue.stringFromDecimal(.zero)
                return WalletsManagmentCellViewModel(
                    isSelected: isSelected,
                    walletName: managedMetaAccount.info.name,
                    fiatBalance: fiatBalance,
                    dayChange: nil,
                    accountScoreViewModel: accountScoreViewModel
                )
            }

            let dayChange = getDayChangeAttributedString(
                currency: walletBalance.currency,
                dayChange: walletBalance.dayChangePercent,
                dayChangeValue: walletBalance.dayChangeValue,
                locale: locale
            )

            let viewModel = WalletsManagmentCellViewModel(
                isSelected: isSelected,
                walletName: managedMetaAccount.info.name,
                fiatBalance: totalFiatValue,
                dayChange: dayChange,
                accountScoreViewModel: accountScoreViewModel
            )
            return viewModel
        }
    }

    private func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .fiat)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
    }

    private func getDayChangeAttributedString(
        currency: Currency,
        dayChange: Decimal,
        dayChangeValue: Decimal,
        locale: Locale
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)
        let dayChangePercent = dayChange.percentString(locale: locale) ?? ""

        var dayChangeValue: String = balanceTokenFormatterValue.stringFromDecimal(abs(dayChangeValue)) ?? ""
        dayChangeValue = "(\(dayChangeValue))"
        let priceWithChangeString = [dayChangePercent, dayChangeValue].joined(separator: " ")
        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = dayChange > 0
            ? R.color.colorGreen()
            : R.color.colorRed()

        if let color = color, let colorLightGray = R.color.colorStrokeGray() {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: 0,
                    length: dayChangePercent.count
                )
            )
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: colorLightGray],
                range: NSRange(
                    location: dayChangePercent.count + 1,
                    length: dayChangeValue.count
                )
            )
        }

        return priceWithChangeAttributed
    }
}
