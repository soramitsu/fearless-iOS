import Foundation
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt
import SSFStorageQueryKit

protocol UserLiquidityPoolsListViewModelFactory {
    func buildViewModel(
        pools: [LiquidityPair]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> LiquidityPoolListViewModel
}

final class UserLiquidityPoolsListViewModelFactoryDefault: UserLiquidityPoolsListViewModelFactory {
    private let modelFactory: LiquidityPoolsModelFactory
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(modelFactory: LiquidityPoolsModelFactory, assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.modelFactory = modelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        pools: [LiquidityPair]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> LiquidityPoolListViewModel {
        let poolViewModels: [LiquidityPoolListCellModel]? = pools?.sorted().compactMap { pair in
            let baseAsset = chain.assets.first(where: { $0.currencyId == pair.baseAssetId })
            let targetAsset = chain.assets.first(where: { $0.currencyId == pair.targetAssetId })
            let rewardAsset = chain.assets.first(where: { $0.currencyId == pair.rewardAssetId })

            guard let baseAsset = baseAsset, let targetAsset = targetAsset, let rewardAsset = rewardAsset else {
                return nil
            }

            let fiatFormatter = fiatFormatter(for: wallet.selectedCurrency, locale: locale)

            let baseAssetIconViewModel = RemoteImageViewModel(url: baseAsset.icon)
            let targetAssetIconViewModel = RemoteImageViewModel(url: targetAsset.icon)

            let iconsViewModel = TokenPairsIconViewModel(firstTokenIconViewModel: baseAssetIconViewModel, secondTokenIconViewModel: targetAssetIconViewModel)
            let tokenPairName = "\(baseAsset.symbol.uppercased())-\(targetAsset.symbol.uppercased())"

            let reservesAddress = pair.reservesId.map { try? AddressFactory.address(for: Data(hex: $0), chain: chain) }
            let rewardTokenNameLabelText = "Earn \(rewardAsset.symbol.uppercased())"
            let apyValue = apyInfos?.first(where: { $0.poolId == reservesAddress })?.apy
            let apyLabelText = apyValue.flatMap { "\($0)% APY" }

            let baseAssetPrice = prices?.first(where: { $0.priceId == baseAsset.priceId })
            let targetAssetPrice = prices?.first(where: { $0.priceId == targetAsset.priceId })
            let poolReservesInfo = reserves?.value?.first(where: { $0.poolId == pair.pairId })
            let reservesValue = modelFactory.buildReserves(
                pool: pair,
                chain: chain,
                reserves: poolReservesInfo,
                baseAssetPrice: baseAssetPrice,
                targetAssetPrice: targetAssetPrice
            )
            let reservesString = reservesValue.flatMap { fiatFormatter.stringFromDecimal($0) }
            let reservesLabelText: String? = reservesString.flatMap { "\($0) TVL" }
            let reservesLabelValue: ShimmeredLabelState = reserves?.type == .cache ? .updating(reservesLabelText) : .normal(reservesLabelText)

            return LiquidityPoolListCellModel(
                tokenPairIconsVieWModel: iconsViewModel,
                tokenPairNameLabelText: tokenPairName,
                rewardTokenNameLabelText: rewardTokenNameLabelText,
                apyLabelText: apyLabelText,
                stakingStatusLabelText: nil,
                reservesLabelValue: reservesLabelValue,
                sortValue: reservesValue.or(.zero)
            )
        }.sorted(by: { $0.sortValue > $1.sortValue })

        return LiquidityPoolListViewModel(
            poolViewModels: poolViewModels,
            titleLabelText: "User pools",
            moreButtonVisible: true
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
}
