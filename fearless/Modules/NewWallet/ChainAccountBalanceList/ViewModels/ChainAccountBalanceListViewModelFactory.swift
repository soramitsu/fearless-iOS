import Foundation

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

        let totalWalletBalance: Decimal = chains.compactMap { chainModel in

            chainModel.assets.compactMap { asset in
                let accountInfo = accountInfos?[chainModel.chainId]

                let balance = getBalance(
                    for: chainModel,
                    asset: asset.asset,
                    accountInfo: accountInfo
                ) ?? ""

                guard let priceId = asset.asset.priceId,
                      let priceData = prices?[priceId],
                      let priceDecimal = Decimal(string: priceData.price),
                      let balanceDecimal = Decimal(string: balance)
                else {
                    return nil
                }

                return priceDecimal * balanceDecimal
            }.reduce(0, +)
        }.reduce(0, +)

        let viewModels: [ChainAccountBalanceCellViewModel] = chains.map { chain in

            chain.assets.compactMap { asset in
                var priceData: PriceData?

                if let prices = prices, let priceId = asset.asset.priceId {
                    priceData = prices[priceId]
                }

                return buildChainAccountBalanceCellViewModel(
                    chain: chain,
                    asset: asset.asset,
                    priceData: priceData,
                    accountInfo: accountInfos?[chain.chainId],
                    locale: locale
                )
            }

        }.reduce([], +)

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
        chain: ChainModel,
        asset: AssetModel,
        priceData: PriceData?,
        accountInfo: AccountInfo?,
        locale: Locale
    ) -> ChainAccountBalanceCellViewModel {
        let icon = buildRemoteImageViewModel(chain: chain)
        let title = chain.name
        let balance = getBalance(
            for: chain,
            asset: asset,
            accountInfo: accountInfo
        )
        let totalAmountString = getUsdBalanceString(
            for: asset,
            chain: chain,
            accountInfo: accountInfo,
            priceData: priceData,
            locale: locale
        )
        let priceAttributedString = getPriceAttributedString(for: asset, priceData: priceData, locale: locale)
        let options = buildChainOptionsViewModel(chain: chain, asset: asset)

        return ChainAccountBalanceCellViewModel(
            asset: asset,
            assetName: chain.name,
            assetInfo: asset.displayInfo(with: chain.icon),
            imageViewModel: icon,
            balanceString: balance,
            priceAttributedString: priceAttributedString,
            totalAmountString: totalAmountString,
            options: options
        )
    }
}

extension ChainAccountBalanceListViewModelFactory {
    private func getBalance(
        for _: ChainModel,
        asset: AssetModel,
        accountInfo: AccountInfo?
    ) -> String? {
        guard let accountInfo = accountInfo else {
            return Decimal.zero.stringWithPointSeparator
        }

        let assetInfo = asset.displayInfo

        let balance = Decimal.fromSubstrateAmount(
            accountInfo.data.available,
            precision: assetInfo.assetPrecision
        ) ?? 0
        return balance.stringWithPointSeparator
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
        for asset: AssetModel,
        chain: ChainModel,
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        locale: Locale
    ) -> String? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        let balance = getBalance(for: chain, asset: asset, accountInfo: accountInfo) ?? ""

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price),
              let balanceDecimal = Decimal(string: balance) else {
            return nil
        }

        let totalBalanceDecimal = priceDecimal * balanceDecimal

        return usdTokenFormatterValue.stringFromDecimal(totalBalanceDecimal)
    }
}

extension ChainAccountBalanceListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountBalanceListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
