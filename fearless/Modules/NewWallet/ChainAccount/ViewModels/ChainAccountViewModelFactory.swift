import Foundation

protocol ChainAccountViewModelFactoryProtocol {
    func buildChainAccountViewModel(
        accountBalanceViewModel: AccountBalanceViewModel,
        assetInfoViewModel: AssetInfoViewModel
    ) -> ChainAccountViewModel

    func buildAccountBalanceViewModel(
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        asset: AssetModel,
        locale: Locale
    ) -> AccountBalanceViewModel

    func buildAssetInfoViewModel(
        chain: ChainModel,
        assetModel: AssetModel,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetInfoViewModel
}

class ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountViewModel(
        accountBalanceViewModel: AccountBalanceViewModel,
        assetInfoViewModel: AssetInfoViewModel
    ) -> ChainAccountViewModel {
        ChainAccountViewModel(
            accountBalanceViewModel: accountBalanceViewModel,
            assetInfoViewModel: assetInfoViewModel
        )
    }

    func buildAccountBalanceViewModel(
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        asset: AssetModel,
        locale: Locale
    ) -> AccountBalanceViewModel {
        let totalAssetValues = AssetAmountValues(
            asset: asset,
            amount: accountInfo?.data.total ?? 0,
            priceData: priceData
        )

        let transferableAssetValues = AssetAmountValues(
            asset: asset,
            amount: accountInfo?.data.available ?? 0,
            priceData: priceData
        )

        let lockedAssetValues = AssetAmountValues(
            asset: asset,
            amount: accountInfo?.data.locked ?? 0,
            priceData: priceData
        )

        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let fiatFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo).value(for: locale)
        let assetFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: asset.displayInfo).value(for: locale)

        return AccountBalanceViewModel(
            totalAmountString: assetFormatter.stringFromDecimal(totalAssetValues.decimalAmount),
            totalAmountFiatString: fiatFormatter.stringFromDecimal(totalAssetValues.fiatAmount),
            transferableAmountString: assetFormatter.stringFromDecimal(transferableAssetValues.decimalAmount),
            transferableAmountFiatString: fiatFormatter.stringFromDecimal(transferableAssetValues.fiatAmount),
            lockedAmountString: assetFormatter.stringFromDecimal(lockedAssetValues.decimalAmount),
            lockedAmountFiatString: fiatFormatter.stringFromDecimal(lockedAssetValues.fiatAmount)
        )
    }

    func buildAssetInfoViewModel(
        chain: ChainModel,
        assetModel: AssetModel,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetInfoViewModel {
        AssetInfoViewModel(
            assetInfo: assetModel.displayInfo,
            imageViewModel: chain.icon.map { buildRemoteImageViewModel(url: $0) },
            priceAttributedString: buildPriceViewModel(
                for: assetModel,
                priceData: priceData,
                locale: locale
            )
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
