import Foundation
import BigInt
import SoraFoundation

// swiftlint:disable function_parameter_count
protocol ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        prices: [AssetModel.PriceId: PriceData]?,
        sortedKeys: [String]?,
        currency: Currency
    ) -> ChainAccountBalanceListViewModel
}

// swiftlint:disable function_body_length
class ChainAccountBalanceListViewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        prices: [AssetModel.PriceId: PriceData]?,
        sortedKeys: [String]?,
        currency: Currency
    ) -> ChainAccountBalanceListViewModel {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)

        var chainAssets = chains
            .filter { selectedMetaAccount.fetch(for: $0.accountRequest()) != nil }
            .map { chain in
                chain.assets.compactMap { asset in
                    ChainAsset(chain: chain, asset: asset.asset)
                }
            }
            .reduce([], +)

        if let assetIdsEnabled = selectedMetaAccount.assetIdsEnabled {
            chainAssets = chainAssets
                .filter {
                    assetIdsEnabled
                        .contains(
                            $0.uniqueKey(accountId: selectedMetaAccount.substrateAccountId)
                        ) == true
                }
        }

        var fiatBalanceByChainAsset: [ChainAsset: Decimal] = [:]
        var balanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            let accountInfo: AccountInfo? = accountInfos?[chainAsset.chain.chainId]

            fiatBalanceByChainAsset[chainAsset] = getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: prices?[chainAsset.asset.priceId ?? ""]
            )

            balanceByChainAsset[chainAsset] = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )
        }

        var orderByKey: [String: Int]?

        if let sortedKeys = sortedKeys {
            orderByKey = [:]
            for (index, key) in sortedKeys.enumerated() {
                orderByKey?[key] = index
            }
        }

        let chainAssetsSorted = chainAssets
            .sorted { ca1, ca2 in
                if let orderByKey = orderByKey {
                    let accountId = selectedMetaAccount.substrateAccountId

                    return orderByKey[ca1.uniqueKey(accountId: accountId)]
                        ?? Int.max < orderByKey[ca2.uniqueKey(accountId: accountId)]
                        ?? Int.max
                } else {
                    return (
                        fiatBalanceByChainAsset[ca1] ?? Decimal.zero,
                        balanceByChainAsset[ca1] ?? Decimal.zero,
                        ca2.chain.isTestnet.intValue,
                        ca1.chain.isPolkadotOrKusama.intValue,
                        ca2.chain.name
                    ) > (
                        fiatBalanceByChainAsset[ca2] ?? Decimal.zero,
                        balanceByChainAsset[ca2] ?? Decimal.zero,
                        ca1.chain.isTestnet.intValue,
                        ca2.chain.isPolkadotOrKusama.intValue,
                        ca1.chain.name
                    )
                }
            }

        let totalWalletBalance: Decimal = chains.compactMap { chainModel in

            chainModel.assets.compactMap { asset in
                let chainAsset = ChainAsset(chain: chainModel, asset: asset.asset)
                let accountInfo = accountInfos?[chainModel.chainId]

                let balanceDecimal = getBalance(
                    for: chainAsset,
                    accountInfo: accountInfo
                )

                guard let priceId = asset.asset.priceId,
                      let priceData = prices?[priceId],
                      let priceDecimal = Decimal(string: priceData.price)
                else {
                    return nil
                }

                return priceDecimal * balanceDecimal
            }.reduce(0, +)
        }.reduce(0, +)

        let viewModels: [ChainAccountBalanceCellViewModel] = chainAssetsSorted.map { chainAsset in
            var priceData: PriceData?

            if let prices = prices, let priceId = chainAsset.asset.priceId {
                priceData = prices[priceId]
            }

            return buildChainAccountBalanceCellViewModel(
                chainAsset: chainAsset,
                priceData: priceData,
                accountInfo: accountInfos?[chainAsset.chain.chainId],
                locale: locale,
                currency: currency
            )
        }

        let haveMissingAccounts = chains.first(where: {
            selectedMetaAccount.fetch(for: $0.accountRequest()) == nil
                && (selectedMetaAccount.unusedChainIds ?? []).contains($0.chainId) == false
        }) != nil

        return ChainAccountBalanceListViewModel(
            accountName: selectedMetaAccount.name,
            balance: balanceTokenFormatterValue.stringFromDecimal(totalWalletBalance),
            accountViewModels: viewModels,
            ethAccountMissed: haveMissingAccounts
        )
    }

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountBalanceCellViewModel(
        chainAsset: ChainAsset,
        priceData: PriceData?,
        accountInfo: AccountInfo?,
        locale: Locale,
        currency: Currency
    ) -> ChainAccountBalanceCellViewModel {
        let icon = chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo, locale: locale
        )
        let totalAmountString = getFiatBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            priceData: priceData,
            locale: locale,
            currency: currency
        )
        let priceAttributedString = getPriceAttributedString(
            for: chainAsset.asset,
            priceData: priceData,
            locale: locale,
            currency: currency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        return ChainAccountBalanceCellViewModel(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            assetName: title,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: icon,
            balanceString: balance,
            priceAttributedString: priceAttributedString,
            totalAmountString: totalAmountString,
            options: options
        )
    }
}

extension ChainAccountBalanceListViewModelFactory {
    private func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
    }

    private func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        locale: Locale
    ) -> String? {
        let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
        let digits = balance > 0 ? 4 : 0
        return balance.toString(locale: locale, digits: digits)
    }

    private func getBalance(
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

    private func getPriceAttributedString(
        for _: AssetModel,
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

    private func getFiatBalanceString(
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

    private func getFiatBalance(
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

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price) else {
            return Decimal.zero
        }

        let totalBalanceDecimal = priceDecimal * balance

        return totalBalanceDecimal
    }
}

extension ChainAccountBalanceListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountBalanceListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
