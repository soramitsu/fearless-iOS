import Foundation
import SoraFoundation

protocol AssetListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated
    ) -> AssetListViewModel
}

final class AssetListViewModelFactory: AssetListViewModelFactoryProtocol {
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    
    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }
    
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey : AccountInfo?],
        prices: PriceDataUpdated
    ) -> AssetListViewModel {
        var enabledChainAssets: [ChainAsset] = chainAssets

        if let assetIdsEnabled = selectedMetaAccount.assetIdsEnabled {
            enabledChainAssets = enabledChainAssets
                .filter {
                    assetIdsEnabled
                        .contains(
                            $0.uniqueKey(accountId: selectedMetaAccount.substrateAccountId)
                        ) == true
                }
        }

        var fiatBalanceByChainAsset: [ChainAsset: Decimal] = [:]

        enabledChainAssets.forEach { chainAsset in
            guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil

            let priceData = prices.pricesData.first(where: { $0.priceId == chainAsset.asset.priceId })
            fiatBalanceByChainAsset[chainAsset] = getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: priceData
            )
        }

        let viewModels: [ChainAccountBalanceCellViewModel] = enabledChainAssets.compactMap { chainAsset in
            let priceId = chainAsset.asset.priceId ?? chainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildChainAccountBalanceCellViewModel(
                chainAssets: enabledChainAssets,
                chainAsset: chainAsset,
                priceData: priceData,
                priceDataUpdated: prices.updated,
                accountInfos: accountInfos,
                locale: locale,
                currency: selectedMetaAccount.selectedCurrency,
                selectedMetaAccount: selectedMetaAccount
            )
        }

        let enabledAccountsInfosKeys = accountInfos.keys.filter { key in
            chainAssets.contains { chainAsset in
                guard
                    let accountId = selectedMetaAccount.fetch(
                        for: chainAsset.chain.accountRequest()
                    )?.accountId else {
                    return false
                }
                let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
                return key == chainAssetKey
            }
        }

        let isColdBoot = enabledAccountsInfosKeys.count != fiatBalanceByChainAsset.count
        return AssetListViewModel(
            accountViewModels: viewModels,
            isColdBoot: isColdBoot
        )
    }
}

private extension AssetListViewModelFactory {
    func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
    }
    
    func buildChainAccountBalanceCellViewModel(
        chainAssets: [ChainAsset],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        priceDataUpdated: Bool,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        currency: Currency,
        selectedMetaAccount: MetaAccountModel
    ) -> ChainAccountBalanceCellViewModel? {
        var icon = (chainAsset.asset.icon ?? chainAsset.chain.icon).map { buildRemoteImageViewModel(url: $0) }
        var title = chainAsset.chain.name

        if chainAsset.chain.parentId == chainAsset.asset.chainId,
           let chain = chainAssets.first(where: { $0.chain.chainId == chainAsset.asset.chainId })?.chain {
            title = chain.name
            icon = chain.icon.map { buildRemoteImageViewModel(url: $0) }
        }

        var accountInfo: AccountInfo?
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfo = accountInfos[key] ?? nil
        }
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            locale: locale
        )
        let totalAmountString = getFiatBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            priceData: priceData,
            locale: locale,
            currency: currency
        )
        let priceAttributedString = getPriceAttributedString(
            priceData: priceData,
            locale: locale,
            currency: currency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        var isColdBoot = true
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let key = chainAsset.uniqueKey(accountId: accountId)
            isColdBoot = !accountInfos.keys.contains(key)
        }

        let viewModel = ChainAccountBalanceCellViewModel(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            assetName: title,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: icon,
            balanceString: .init(
                value: .text(balance),
                isUpdated: priceDataUpdated
            ),
            priceAttributedString: .init(
                value: .attributed(priceAttributedString),
                isUpdated: priceDataUpdated
            ),
            totalAmountString: .init(
                value: .text(totalAmountString),
                isUpdated: priceDataUpdated
            ),
            options: options,
            isColdBoot: isColdBoot,
            priceDataWasUpdated: priceDataUpdated
        )

        if selectedMetaAccount.assetFilterOptions.contains(.hideZeroBalance),
           accountInfo == nil,
           !isColdBoot {
            return nil
        } else {
            return viewModel
        }
    }
    
    func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        locale: Locale
    ) -> String? {
        let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
        let digits = balance > 0 ? 4 : 0
        return balance.toString(locale: locale, digits: digits)
    }

    func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        guard let accountInfo = accountInfo else {
            return Decimal.zero
        }

        let assetInfo = chainAsset.asset.displayInfo

        let balance = Decimal.fromSubstrateAmount(
            accountInfo.data.total,
            precision: assetInfo.assetPrecision
        ) ?? 0

        return balance
    }
    
    func getFiatBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        locale: Locale,
        currency: Currency
    ) -> String? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)

        return balanceTokenFormatterValue.stringFromDecimal(
            getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: priceData
            )
        )
    }
    
    func getFiatBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?
    ) -> Decimal {
        let assetInfo = chainAsset.asset.displayInfo

        var balance: Decimal
        if let accountInfo = accountInfo {
            balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: assetInfo.assetPrecision
            ) ?? 0
        } else {
            balance = Decimal.zero
        }

        guard let price = priceData?.price,
              let priceDecimal = Decimal(string: price) else {
            return Decimal.zero
        }

        let totalBalanceDecimal = priceDecimal * balance

        return totalBalanceDecimal
    }
    
    private func getPriceAttributedString(
        priceData: PriceData?,
        locale: Locale,
        currency: Currency
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price) else {
            return nil
        }

        let changeString: String = priceData.fiatDayChange.map {
            let percentValue = $0 / 100
            return percentValue.percentString(locale: locale) ?? ""
        } ?? ""

        let priceString: String = balanceTokenFormatterValue.stringFromDecimal(priceDecimal) ?? ""
        let priceWithChangeString = [priceString, changeString].joined(separator: " ")
        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = (priceData.fiatDayChange ?? 0) > 0
            ? R.color.colorGreen()
            : R.color.colorRed()

        if let color = color {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: priceString.count + 1,
                    length: changeString.count
                )
            )
        }

        return priceWithChangeAttributed
    }
}

extension AssetListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension AssetListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
