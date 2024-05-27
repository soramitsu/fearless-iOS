import Foundation
import SoraFoundation
import SSFModels

protocol BalanceInfoViewModelFactoryProtocol {
    func buildBalanceInfo(
        with type: BalanceInfoType,
        balances: WalletBalanceInfos,
        infoButtonEnabled: Bool,
        locale: Locale
    ) -> BalanceInfoViewModel
}

final class BalanceInfoViewModelFactory: BalanceInfoViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildBalanceInfo(
        with type: BalanceInfoType,
        balances: WalletBalanceInfos,
        infoButtonEnabled: Bool,
        locale: Locale
    ) -> BalanceInfoViewModel {
        var balanceInfoViewModel: BalanceInfoViewModel

        switch type {
        case let .wallet(metaAccount):
            guard let info = balances[metaAccount.metaId] else {
                return zeroBalanceViewModel(
                    balanceString: metaAccount.selectedCurrency.symbol + "0",
                    infoButtonEnabled: false
                )
            }
            balanceInfoViewModel = buildWalletBalance(
                with: info,
                locale: locale
            )

        case let .chainAsset(metaAccount, chainAsset):
            guard let info = balances[metaAccount.metaId] else {
                return zeroBalanceViewModel(
                    balanceString: "0 " + chainAsset.asset.symbol.uppercased(),
                    infoButtonEnabled: false
                )
            }
            balanceInfoViewModel = buildChainAssetBalance(
                with: info,
                metaAccount: metaAccount,
                chainAsset: chainAsset,
                infoButtonEnabled: infoButtonEnabled,
                locale: locale
            )
        case let .chainAssets(chainAssets, wallet):
            let symbol = chainAssets.first?.asset.symbol.uppercased() ?? ""
            guard let info = balances[wallet.metaId] else {
                return zeroBalanceViewModel(
                    balanceString: "0 " + symbol,
                    infoButtonEnabled: false
                )
            }
            balanceInfoViewModel = buildChainAssetsBalance(
                with: info,
                metaAccount: wallet,
                chainAssets: chainAssets,
                infoButtonEnabled: infoButtonEnabled,
                locale: locale
            )
        }

        return balanceInfoViewModel
    }

    private func buildWalletBalance(
        with balanceInfo: WalletBalanceInfo,
        locale: Locale
    ) -> BalanceInfoViewModel {
        let balanceTokenFormatterValue = tokenFormatter(
            for: balanceInfo.currency,
            locale: locale
        )

        let totalBalance = balanceTokenFormatterValue.stringFromDecimal(balanceInfo.enabledAssetFiatBalance) ?? "0"
        let dayChangeAttributedString = getDayChangeAttributedString(
            currency: balanceInfo.currency,
            dayChange: balanceInfo.dayChangePercent,
            dayChangeValue: balanceInfo.dayChangeValue,
            locale: locale
        )

        return BalanceInfoViewModel(
            dayChangeAttributedString: dayChangeAttributedString,
            balanceString: totalBalance,
            infoButtonEnabled: false
        )
    }

    private func buildChainAssetBalance(
        with balanceInfo: WalletBalanceInfo,
        metaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        infoButtonEnabled: Bool,
        locale: Locale
    ) -> BalanceInfoViewModel {
        let accountRequest = chainAsset.chain.accountRequest()
        guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
            return zeroBalanceViewModel(
                balanceString: "0 " + chainAsset.asset.symbol.uppercased(),
                infoButtonEnabled: false
            )
        }

        let dayChangeAttributedString = getDayChangeAttributedString(
            currency: balanceInfo.currency,
            dayChange: balanceInfo.dayChangePercent,
            dayChangeValue: balanceInfo.dayChangeValue,
            locale: locale
        )

        let displayInfo = chainAsset.asset.displayInfo
        let assetFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .listCrypto).value(for: locale)

        let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
        guard
            let accountInfo = balanceInfo.accountInfos[chainAssetKey] ?? nil,
            let balance = Decimal.fromSubstrateAmount(
                accountInfo.data.sendAvailable,
                precision: displayInfo.assetPrecision
            ),
            let balanceString = assetFormatter.stringFromDecimal(balance)
        else {
            return zeroBalanceViewModel(
                balanceString: "0 " + chainAsset.asset.symbol.uppercased(),
                infoButtonEnabled: infoButtonEnabled
            )
        }

        return BalanceInfoViewModel(
            dayChangeAttributedString: dayChangeAttributedString,
            balanceString: balanceString,
            infoButtonEnabled: infoButtonEnabled
        )
    }

    private func buildChainAssetsBalance(
        with balanceInfo: WalletBalanceInfo,
        metaAccount: MetaAccountModel,
        chainAssets: [ChainAsset],
        infoButtonEnabled: Bool,
        locale: Locale
    ) -> BalanceInfoViewModel {
        guard let chainAsset = chainAssets.first else {
            return zeroBalanceViewModel(balanceString: "0", infoButtonEnabled: infoButtonEnabled)
        }
        let displayInfo = chainAsset.asset.displayInfo
        let assetFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .listCrypto).value(for: locale)

        let dayChangeAttributedString = getDayChangeAttributedString(
            currency: balanceInfo.currency,
            dayChange: balanceInfo.dayChangePercent,
            dayChangeValue: balanceInfo.dayChangeValue,
            locale: locale
        )

        let balances: [Decimal] = chainAssets.compactMap { chainAsset -> Decimal? in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return 0
            }

            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            guard
                let accountInfo = balanceInfo.accountInfos[chainAssetKey] ?? nil,
                let balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.sendAvailable,
                    precision: chainAsset.asset.displayInfo.assetPrecision
                ) else {
                return 0
            }

            return balance
        }

        let balance: Decimal = balances.reduce(0, +)

        guard let balanceString = assetFormatter.stringFromDecimal(balance) else {
            return zeroBalanceViewModel(
                balanceString: "0 " + chainAsset.asset.symbol.uppercased(),
                infoButtonEnabled: infoButtonEnabled
            )
        }

        return BalanceInfoViewModel(
            dayChangeAttributedString: dayChangeAttributedString,
            balanceString: balanceString,
            infoButtonEnabled: infoButtonEnabled
        )
    }

    private func zeroBalanceViewModel(
        balanceString: String,
        infoButtonEnabled: Bool
    ) -> BalanceInfoViewModel {
        BalanceInfoViewModel(
            dayChangeAttributedString: nil,
            balanceString: balanceString,
            infoButtonEnabled: infoButtonEnabled
        )
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

        if let color = color, let colorLightGray = R.color.colorLightGray() {
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
