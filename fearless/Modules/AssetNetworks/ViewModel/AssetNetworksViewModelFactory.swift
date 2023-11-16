import Foundation
import SSFModels
import BigInt
import SoraFoundation

protocol AssetNetworksViewModelFactoryProtocol {
    func buildViewModels(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        wallet: MetaAccountModel,
        locale: Locale,
        filter: AssetNetworksFilter,
        sort: AssetNetworksSortType
    ) -> [AssetNetworksTableCellModel]
}

final class AssetNetworksViewModelFactory: AssetNetworksViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(balanceViewModelFactory: AssetBalanceFormatterFactoryProtocol) {
        assetBalanceFormatterFactory = balanceViewModelFactory
    }

    func buildViewModels(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        wallet: MetaAccountModel,
        locale: Locale,
        filter: AssetNetworksFilter,
        sort _: AssetNetworksSortType
    ) -> [AssetNetworksTableCellModel] {
        let viewModels: [AssetNetworksTableCellModel] = chainAssets.compactMap { chainAsset -> AssetNetworksTableCellModel? in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }

            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil

            if filter == .myNetworks, accountInfo?.data.sendAvailable == BigUInt.zero {
                return nil
            }

            let price = prices.pricesData.first(where: { $0.priceId == chainAsset.asset.priceId })

            let balanceDecimal = Decimal.fromSubstrateAmount(accountInfo?.data.sendAvailable ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0.0

            let cryptoBalanceLabelText = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .listCrypto).value(for: locale).stringFromDecimal(balanceDecimal)

            let fiatBalanceLabelText = fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(Decimal(string: (price?.price) ?? "") ?? 0)

            return AssetNetworksTableCellModel(
                iconViewModel: chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) },
                chainNameLabelText: chainAsset.chain.name,
                cryptoBalanceLabelText: cryptoBalanceLabelText,
                fiatBalanceLabelText: fiatBalanceLabelText,
                chainAsset: chainAsset
            )
        }

        return viewModels
    }

    private func fiatFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .fiat)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
    }
}

extension AssetNetworksViewModelFactory: RemoteImageViewModelFactoryProtocol {}
