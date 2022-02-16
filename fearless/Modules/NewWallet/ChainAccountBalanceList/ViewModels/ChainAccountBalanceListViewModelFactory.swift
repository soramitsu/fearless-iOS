import Foundation
import BigInt

protocol ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel?,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        prices: [AssetModel.PriceId: PriceData]?
    ) -> ChainAccountBalanceListViewModel
}

class ChainAccountBalanceListViewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol {
    func buildChainAccountBalanceListViewModel(
        selectedMetaAccount: MetaAccountModel?,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        prices: [AssetModel.PriceId: PriceData]?
    ) -> ChainAccountBalanceListViewModel {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        var chainAssets = chains.map { chain in
            chain.assets.compactMap { asset in
                ChainAsset(chain: chain, asset: asset.asset)
            }
        }
        .reduce([], +)

        var usdBalanceByChainAsset: [ChainAsset: Decimal] = [:]
        var balanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            let accountInfo: AccountInfo? = accountInfos?[chainAsset.chain.chainId]

            usdBalanceByChainAsset[chainAsset] = getUsdBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: prices?[chainAsset.asset.priceId ?? ""],
                locale: locale
            )

            balanceByChainAsset[chainAsset] = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )
        }

        let chainAssetsSorted = chainAssets
            .sorted { ca1, ca2 in
                (
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
                locale: locale
            )
        }

        return ChainAccountBalanceListViewModel(
            accountName: selectedMetaAccount?.name,
            balance: usdTokenFormatterValue.stringFromDecimal(totalWalletBalance),
            accountViewModels: viewModels
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
        locale: Locale
    ) -> ChainAccountBalanceCellViewModel {
        let icon = chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo
        )
        let totalAmountString = getUsdBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            priceData: priceData,
            locale: locale
        )
        let priceAttributedString = getPriceAttributedString(
            for: chainAsset.asset,
            priceData: priceData,
            locale: locale
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        return ChainAccountBalanceCellViewModel(
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
    private func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> String? {
        let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
        let digits = balance > 0 ? 4 : 0
        return balance.toString(digits: digits)
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
            return percentValue.percentString() ?? ""
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

        return usdTokenFormatterValue.stringFromDecimal(getUsdBalance(for: chainAsset, accountInfo: accountInfo, priceData: priceData, locale: locale))
    }

    private func getUsdBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        locale: Locale
    ) -> Decimal {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

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
