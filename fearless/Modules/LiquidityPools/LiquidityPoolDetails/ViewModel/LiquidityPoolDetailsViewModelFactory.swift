import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SSFStorageQueryKit
import SoraFoundation

protocol LiquidityPoolDetailsViewModelFactory {
    func buildViewModel(
        liquidityPair: LiquidityPair,
        reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?,
        apyInfo: PoolApyInfo?,
        chain: ChainModel,
        locale: Locale,
        wallet: MetaAccountModel,
        accountPoolInfo: AccountPool?,
        input: LiquidityPoolDetailsInput
    ) -> LiquidityPoolDetailsViewModel?
}

final class LiquidityPoolDetailsViewModelFactoryDefault: LiquidityPoolDetailsViewModelFactory {
    private let modelFactory: LiquidityPoolsModelFactory
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        modelFactory: LiquidityPoolsModelFactory,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.modelFactory = modelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        liquidityPair: LiquidityPair,
        reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?,
        apyInfo: PoolApyInfo?,
        chain: ChainModel,
        locale: Locale,
        wallet: MetaAccountModel,
        accountPoolInfo: AccountPool?,
        input: LiquidityPoolDetailsInput
    ) -> LiquidityPoolDetailsViewModel? {
        guard
            let baseAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.baseAssetId }),
            let targetAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.targetAssetId }),
            let rewardAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.rewardAssetId })
        else {
            return nil
        }

        let fiatFormatter = fiatFormatter(for: wallet.selectedCurrency, locale: locale)

        let baseAssetPrice = baseAsset.getPrice(for: wallet.selectedCurrency)
        let targetAssetPrice = targetAsset.getPrice(for: wallet.selectedCurrency)

        let reservesValue = modelFactory.buildReserves(
            pool: liquidityPair,
            chain: chain,
            reservesInfo: reserves?.value,
            baseAssetPrice: baseAssetPrice,
            targetAssetPrice: targetAssetPrice
        )
        let reservesString = reservesValue.flatMap { fiatFormatter.stringFromDecimal($0) }

        let apyLabelText = apyInfo?.apy.flatMap { NumberFormatter.percentAPY.stringFromDecimal($0) }
        let tokenPairsIconViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: RemoteImageViewModel(url: baseAsset.icon),
            rightViewModel: RemoteImageViewModel(url: targetAsset.icon),
            leftShadowColor: HexColorConverter.hexStringToUIColor(hex: baseAsset.color)?.cgColor,
            rightShadowColor: HexColorConverter.hexStringToUIColor(hex: targetAsset.color)?.cgColor
        )

        let baseAssetBalanceViewModelFactory = createBalanceViewModelFactory(for: ChainAsset(chain: chain, asset: baseAsset), wallet: wallet)
        let targetAssetBalanceViewModelFactory = createBalanceViewModelFactory(for: ChainAsset(chain: chain, asset: targetAsset), wallet: wallet)

        let baseAssetViewModel = accountPoolInfo?.baseAssetPooled.flatMap {
            baseAssetBalanceViewModelFactory.balanceFromPrice($0, priceData: baseAssetPrice, usageCase: .detailsCrypto)
        }

        let targetAssetViewModel = accountPoolInfo?.targetAssetPooled.flatMap {
            targetAssetBalanceViewModelFactory.balanceFromPrice($0, priceData: targetAssetPrice, usageCase: .detailsCrypto)
        }
        let reservesViewModel = reservesString.flatMap { TitleMultiValueViewModel(title: $0, subtitle: nil) }
        let apyViewModel = apyLabelText.flatMap { TitleMultiValueViewModel(title: $0, subtitle: nil) }

        return LiquidityPoolDetailsViewModel(
            pairTitleLabelText: "\(baseAsset.symbol.uppercased()) › \(targetAsset.symbol.uppercased())",
            baseAssetName: baseAsset.symbol.uppercased(),
            targetAssetName: targetAsset.symbol.uppercased(),
            reservesViewModel: reservesViewModel,
            apyViewModel: apyViewModel,
            rewardTokenLabelText: rewardAsset.symbol.uppercased(),
            baseAssetViewModel: baseAssetViewModel?.value(for: locale),
            targetAssetViewModel: targetAssetViewModel?.value(for: locale),
            tokenPairIconsViewModel: tokenPairsIconViewModel,
            userPoolFieldsHidden: !input.isUserPool && accountPoolInfo == nil,
            rewardTokenIconViewModel: RemoteImageViewModel(url: rewardAsset.icon)
        )
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

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset, wallet: MetaAccountModel) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
    }
}
