import Foundation
import BigInt
import SoraFoundation

// swiftlint:disable function_parameter_count
protocol ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo?],
        prices: [AssetModel.PriceId: PriceDataUpdated],
        sortedKeys: [String]?
    ) -> ChainAccountBalanceListViewModel
}

// swiftlint:disable function_body_length
class ChainAccountBalanceListViewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo?],
        prices: [AssetModel.PriceId: PriceDataUpdated],
        sortedKeys: [String]?
    ) -> ChainAccountBalanceListViewModel {
        let balanceTokenFormatterValue = tokenFormatter(
            for: selectedMetaAccount.selectedCurrency,
            locale: locale
        )

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
            let accountInfo = accountInfos[chainAsset.chain.chainId] ?? nil

            fiatBalanceByChainAsset[chainAsset] = getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: prices[chainAsset.asset.priceId ?? ""]?.priceData
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
                let accountInfo = accountInfos[chainModel.chainId] ?? nil

                let balanceDecimal = getBalance(
                    for: chainAsset,
                    accountInfo: accountInfo
                )

                guard let priceId = asset.asset.priceId,
                      let priceData = prices[priceId]?.priceData,
                      let priceDecimal = Decimal(string: priceData.price)
                else {
                    return nil
                }

                return priceDecimal * balanceDecimal
            }.reduce(0, +)
        }.reduce(0, +)

        let viewModels: [ChainAccountBalanceCellViewModel] = chainAssetsSorted.map { chainAsset in
            var priceData: PriceDataUpdated?

            if let priceId = chainAsset.asset.priceId {
                priceData = prices[priceId]
            } else {
                priceData = prices[chainAsset.asset.id]
            }

            return buildChainAccountBalanceCellViewModel(
                chainAsset: chainAsset,
                priceData: priceData,
                accountInfos: accountInfos,
                locale: locale,
                currency: selectedMetaAccount.selectedCurrency
            )
        }

        let haveMissingAccounts = chains.first(where: {
            selectedMetaAccount.fetch(for: $0.accountRequest()) == nil
                && (selectedMetaAccount.unusedChainIds ?? []).contains($0.chainId) == false
        }) != nil

        let isColdBoot = accountInfos.keys.count != chains.count
        let balanceUpdated = prices.filter { $0.value.updated == false }.isEmpty

        let balance = balanceTokenFormatterValue.stringFromDecimal(totalWalletBalance)
        return ChainAccountBalanceListViewModel(
            accountName: selectedMetaAccount.name,
            balance: .init(value: .text(balance), isUpdated: balanceUpdated && !isColdBoot),
            accountViewModels: viewModels,
            ethAccountMissed: haveMissingAccounts,
            isColdBoot: isColdBoot
        )
    }

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountBalanceCellViewModel(
        chainAsset: ChainAsset,
        priceData: PriceDataUpdated?,
        accountInfos: [ChainModel.Id: AccountInfo?],
        locale: Locale,
        currency: Currency
    ) -> ChainAccountBalanceCellViewModel {
        let icon = chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name

        let accountInfo = accountInfos[chainAsset.chain.chainId] ?? nil
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            locale: locale
        )
        let totalAmountString = getFiatBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            priceData: priceData?.priceData,
            locale: locale,
            currency: currency
        )
        let priceAttributedString = getPriceAttributedString(
            priceData: priceData?.priceData,
            locale: locale,
            currency: currency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        let isColdBoot = !accountInfos.keys.contains(chainAsset.chain.chainId)
        let isUpdated = priceData?.updated ?? false

        return ChainAccountBalanceCellViewModel(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            assetName: title,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: icon,
            balanceString: .init(
                value: .text(balance),
                isUpdated: isUpdated
            ),
            priceAttributedString: .init(
                value: .attributed(priceAttributedString),
                isUpdated: isUpdated
            ),
            totalAmountString: .init(
                value: .text(totalAmountString),
                isUpdated: isUpdated
            ),
            options: options,
            isColdBoot: isColdBoot,
            priceDataWasUpdated: isUpdated
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
