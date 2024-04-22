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
        sort: AssetNetworksSortType,
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings]
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
        sort: AssetNetworksSortType,
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings]
    ) -> [AssetNetworksTableCellModel] {
        let viewModels: [AssetNetworksTableCellModel] = chainAssets.sorted(by: { ca1, ca2 in
            switch sort {
            case .fiat:
                guard
                    let accountId1 = wallet.fetch(for: ca1.chain.accountRequest())?.accountId,
                    let accountId2 = wallet.fetch(for: ca2.chain.accountRequest())?.accountId
                else {
                    return false
                }

                let accountInfo1 = accountInfos[ca1.uniqueKey(accountId: accountId1)] ?? nil
                let accountInfo2 = accountInfos[ca2.uniqueKey(accountId: accountId2)] ?? nil

                let price1 = prices.pricesData.first(where: { $0.priceId == ca1.asset.priceId })
                let price2 = prices.pricesData.first(where: { $0.priceId == ca2.asset.priceId })

                let price1Value = (price1?.price).map { Decimal(string: $0).or(.zero) }.or(.zero)
                let price2Value = (price2?.price).map { Decimal(string: $0).or(.zero) }.or(.zero)

                let balanceDecimal1 = Decimal.fromSubstrateAmount(accountInfo1?.data.sendAvailable ?? BigUInt.zero, precision: Int16(ca1.asset.precision)) ?? 0.0
                let balanceDecimal2 = Decimal.fromSubstrateAmount(accountInfo2?.data.sendAvailable ?? BigUInt.zero, precision: Int16(ca2.asset.precision)) ?? 0.0

                let fiatBalance1 = balanceDecimal1 * price1Value
                let fiatBalance2 = balanceDecimal2 * price2Value

                return fiatBalance1 > fiatBalance2
            case .popularity:
                return ca1.chain.rank.or(0) > ca2.chain.rank.or(0)
            case .name:
                return ca1.chain.name < ca2.chain.name
            }
        }).compactMap { chainAsset -> AssetNetworksTableCellModel? in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }

            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil

            if filter == .myNetworks, accountInfo?.data.sendAvailable == BigUInt.zero || accountInfo == nil {
                return nil
            }

            let price = prices.pricesData.first(where: { $0.priceId == chainAsset.asset.priceId })
            let priceValue = (price?.price).map { Decimal(string: $0).or(.zero) }.or(.zero)
            let balanceDecimal = Decimal.fromSubstrateAmount(accountInfo?.data.sendAvailable ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0.0

            let cryptoBalanceLabelText = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .listCryptoWith(minimumFractionDigits: 0, maximumFractionDigits: 3)).value(for: locale).stringFromDecimal(balanceDecimal)

            let fiatBalance = balanceDecimal * priceValue
            let fiatBalanceLabelText = fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(fiatBalance)
            let hasIssues = checkHasIssue(
                chain: chainAsset.chain,
                wallet: wallet,
                chainsWithIssue: chainsWithIssue,
                chainSettings: chainSettings
            )

            return AssetNetworksTableCellModel(
                iconViewModel: chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) },
                chainNameLabelText: chainAsset.chain.name,
                cryptoBalanceLabelText: cryptoBalanceLabelText,
                fiatBalanceLabelText: fiatBalanceLabelText,
                chainAsset: chainAsset,
                hasIssues: hasIssues.hasAccountIssue || hasIssues.hasNetworkIssue
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
extension AssetNetworksViewModelFactory: ChainAssetListBuilder {}
