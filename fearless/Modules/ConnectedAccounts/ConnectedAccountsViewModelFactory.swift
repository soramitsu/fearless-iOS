import Foundation
import SoraFoundation
import SSFModels
import SoraKeystore

protocol ConnectedAccountsViewModelFactory {
    func buildViewModel(
        wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        chains: [ChainModel],
        locale: Locale
    ) -> [ConnectedAccountsViewModel]
}

final class ConnectedAccountsViewModelFactoryImpl: ConnectedAccountsViewModelFactory {

    private lazy var assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
    private let accountScoreFetcher: AccountStatisticsFetching
    private let settings: SettingsManagerProtocol

    init(
        accountScoreFetcher: AccountStatisticsFetching,
        settings: SettingsManagerProtocol
    ) {
        self.accountScoreFetcher = accountScoreFetcher
        self.settings = settings
    }

    func buildViewModel(
        wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        chains: [ChainModel],
        locale: Locale
    ) -> [ConnectedAccountsViewModel] {
        let walletViewModel = createUserViewModel(
            from: wallet,
            balance: balance,
            locale: locale
        )

        let accountsViewModel = createAccountsViewModel(
            chains: chains,
            wallet: wallet
        )

        let viewModel: [ConnectedAccountsViewModel] = [
            .wallet(walletViewModel),
            .accounts(accountsViewModel)
        ]
        return viewModel
    }

    // MARK: - Private methods

    private func createUserViewModel(
        from wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        locale: Locale
    ) -> WalletsManagmentCellViewModel {
        var fiatBalance: String = ""
        var dayChange: NSAttributedString?
        if let balance = balance {
            let formatter = tokenFormatter(for: balance.currency, locale: locale)
            fiatBalance = formatter.stringFromDecimal(balance.totalFiatValue) ?? ""
            dayChange = getDayChangeAttributedString(
                currency: balance.currency,
                dayChange: balance.dayChangePercent,
                dayChangeValue: balance.dayChangeValue,
                locale: locale
            )
        }

        return WalletsManagmentCellViewModel(
            isSelected: false,
            walletName: wallet.name,
            icon: wallet.icon(),
            fiatBalance: fiatBalance,
            dayChange: dayChange,
            accountScoreViewModel: nil,
            optionsAvailable: wallet.ecosystem.isRegular
        )
    }

    private func createAccountsViewModel(
        chains: [ChainModel],
        wallet: MetaAccountModel
    ) -> [ConnectedAccountsViewModel.Accounts] {
        var accountsViewModel: [ConnectedAccountsViewModel.Accounts] = []

        let mapped = chains.reduce([Ecosystem: [ChainModel]]()) { partialResult, chain in
            var part = partialResult
            switch chain.ecosystem {
            case .substrate, .ethereum:
                var possibleValues = partialResult[chain.ecosystem] ?? []
                possibleValues.append(chain)
                part[chain.ecosystem] = possibleValues
            case .ethereumBased:
                var possibleValues = partialResult[.ethereum] ?? []
                possibleValues.append(chain)
                part[.ethereum] = possibleValues
            case .ton:
                break
            }
            return part
        }

        mapped.forEach { ecosystem, chains in
            let title: String
            var count: Int?
            switch ecosystem {
            case .substrate:
                title = "Substrate chain accounts"
                count = chains.map { wallet.fetch(for: $0.accountRequest())?.accountId }.filter { $0 != nil }.count
            case .ethereum, .ethereumBased:
                title = "EVM chain accounts"
                count = chains.map { wallet.fetch(for: $0.accountRequest())?.accountId }.filter { $0 != nil }.count
            case .ton:
                title = "TON chain accounts"
                count = chains.map { wallet.fetch(for: $0.accountRequest())?.accountId }.filter { $0 != nil }.count
            }
            if count == 0 {
                count = nil
            }
            let accounts = ConnectedAccountsViewModel.Accounts(
                title: title,
                count: count,
                ecosystem: ecosystem,
                chains: chains
            )
            accountsViewModel.append(accounts)
        }

        return accountsViewModel.sorted(by: { $0.count.or(.zero) > $1.count.or(.zero) })
    }

    private func tokenFormatter(for currency: Currency, locale: Locale) -> TokenFormatter {
        let balanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo, usageCase: .detailsCrypto)
        let balanceTokenFormatterValue = balanceTokenFormatter.value(for: locale)
        return balanceTokenFormatterValue
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
