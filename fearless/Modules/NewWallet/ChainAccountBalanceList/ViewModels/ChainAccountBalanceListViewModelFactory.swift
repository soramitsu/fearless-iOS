import Foundation
import BigInt

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

class ChainAccountBalanceListViewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo?],
        prices: [AssetModel.PriceId: PriceDataUpdated],
        sortedKeys: [String]?
    ) -> ChainAccountBalanceListViewModel {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        var chainAssets = chains
            .filter { selectedMetaAccount.fetch(for: $0.accountRequest()) != nil }
            .map { chain in
                chain.assets.compactMap { asset in
                    ChainAsset(chain: chain, asset: asset.asset)
                }
            }
            .reduce([], +)

        if let assetIdsEnabled = selectedMetaAccount.assetIdsEnabled {
            chainAssets = chainAssets.filter { assetIdsEnabled.contains($0.uniqueKey(accountId: selectedMetaAccount.substrateAccountId)) == true }
        }

        var usdBalanceByChainAsset: [ChainAsset: Decimal] = [:]
        var balanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            let accountInfo = accountInfos[chainAsset.chain.chainId] ?? nil

            usdBalanceByChainAsset[chainAsset] = getUsdBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: prices[chainAsset.asset.priceId ?? ""]?.priceData
            )

            balanceByChainAsset[chainAsset] = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )
        }

        let useSortedKeys: Bool = sortedKeys != nil
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

                    return orderByKey[ca1.uniqueKey(accountId: accountId)] ?? Int.max < orderByKey[ca2.uniqueKey(accountId: accountId)] ?? Int.max
                } else {
                    return (
                        usdBalanceByChainAsset[ca1] ?? Decimal.zero,
                        balanceByChainAsset[ca1] ?? Decimal.zero,
                        ca2.chain.isTestnet.intValue,
                        ca1.chain.isPolkadotOrKusama.intValue,
                        ca2.chain.name
                    ) > (
                        usdBalanceByChainAsset[ca2] ?? Decimal.zero,
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
                locale: locale
            )
        }

        let haveMissingAccounts = chains.first(where: {
            selectedMetaAccount.fetch(for: $0.accountRequest()) == nil
                && (selectedMetaAccount.unusedChainIds ?? []).contains($0.chainId) == false
        }) != nil

        let isColdBoot = accountInfos.keys.count != chains.count
        let balanceUpdated = prices.filter { $0.value.updated == false }.isEmpty

        let balance = usdTokenFormatterValue.stringFromDecimal(totalWalletBalance)
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
        locale: Locale
    ) -> ChainAccountBalanceCellViewModel {
        let icon = chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name

        let accountInfo = accountInfos[chainAsset.chain.chainId] ?? nil
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            locale: locale
        )
        let totalAmountString = getUsdBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            priceData: priceData?.priceData,
            locale: locale
        )
        let priceAttributedString = getPriceAttributedString(
            priceData: priceData?.priceData,
            locale: locale
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
        locale: Locale
    ) -> NSAttributedString? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price) else {
            return nil
        }

        let changeString: String = priceData.usdDayChange.map {
            let percentValue = $0 / 100
            return percentValue.percentString(locale: locale) ?? ""
        } ?? ""

        let priceString: String = usdTokenFormatterValue.stringFromDecimal(priceDecimal) ?? ""

        let priceWithChangeString = [priceString, changeString].joined(separator: " ")

        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = (priceData.usdDayChange ?? 0) > 0 ? R.color.colorGreen() : R.color.colorRed()

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

    private func getUsdBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        locale: Locale
    ) -> String? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        return usdTokenFormatterValue.stringFromDecimal(getUsdBalance(for: chainAsset, accountInfo: accountInfo, priceData: priceData))
    }

    private func getUsdBalance(
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
