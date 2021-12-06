import Foundation

protocol ChainAccountViewModelFactoryProtocol {
    func buildChainAccountViewModel(accountBalanceViewModel: AccountBalanceViewModel) -> ChainAccountViewModel
    func buildAccountBalanceViewModel(
        accountInfo: AccountInfo?,
        priceData: PriceData?,
        asset: AssetModel,
        locale: Locale
    ) -> AccountBalanceViewModel
}

class ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactory

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactory) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountViewModel(accountBalanceViewModel: AccountBalanceViewModel) -> ChainAccountViewModel {
        ChainAccountViewModel(accountBalanceViewModel: accountBalanceViewModel)
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

        let fiatFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: AssetBalanceDisplayInfo.usd()).value(for: locale)
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
}
