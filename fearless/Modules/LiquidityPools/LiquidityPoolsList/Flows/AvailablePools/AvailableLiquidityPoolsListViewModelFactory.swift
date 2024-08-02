import Foundation
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt
import SSFStorageQueryKit

protocol AvailableLiquidityPoolsListViewModelFactory {
    func buildViewModel(
        pairs: [LiquidityPair]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel,
        type: LiquidityPoolListType,
        searchText: String?
    ) -> LiquidityPoolListViewModel

    func buildLoadingViewModel(
        type: LiquidityPoolListType,
        locale: Locale
    ) -> LiquidityPoolListViewModel
}

final class AvailableLiquidityPoolsListViewModelFactoryDefault: AvailableLiquidityPoolsListViewModelFactory {
    private let modelFactory: LiquidityPoolsModelFactory
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(modelFactory: LiquidityPoolsModelFactory, assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.modelFactory = modelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    private func buildLoadingCellViewModel() -> LiquidityPoolListCellModel {
        let tokenPairIconsViewModel = TokenPairsIconViewModel(
            firstTokenIconViewModel: nil,
            secondTokenIconViewModel: nil
        )

        return LiquidityPoolListCellModel(
            tokenPairIconsVieWModel: tokenPairIconsViewModel,
            tokenPairNameLabelText: nil,
            rewardTokenNameLabelText: nil,
            apyLabelText: nil,
            stakingStatusLabelText: nil,
            reservesLabelText: nil,
            sortValue: 0,
            liquidityPair: nil
        )
    }

    func buildLoadingViewModel(type: LiquidityPoolListType, locale: Locale) -> LiquidityPoolListViewModel {
        var poolViewModels: [LiquidityPoolListCellModel] = []
        for _ in 0 ... 19 {
            poolViewModels.append(buildLoadingCellViewModel())
        }

        return LiquidityPoolListViewModel(
            poolViewModels: poolViewModels,
            titleLabelText: R.string.localizable.lpAvailablePoolsTitle(preferredLanguages: locale.rLanguages),
            moreButtonVisible: type == .embed,
            backgroundVisible: type == .full,
            refreshAvailable: type == .full,
            isEmbed: type == .embed
        )
    }

    func buildViewModel(
        pairs: [LiquidityPair]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel,
        type: LiquidityPoolListType,
        searchText: String?
    ) -> LiquidityPoolListViewModel {
        let poolViewModels: [LiquidityPoolListCellModel]? = pairs?.sorted().compactMap { pair in
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
            let rewardTokenNameLabelText = R.string.localizable.lpRewardTokenText(rewardAsset.symbol.uppercased(), preferredLanguages: locale.rLanguages)
            let apyValue = apyInfos?.first(where: { $0.poolId == reservesAddress })?.apy
            let apyLabelText = apyValue.flatMap { NumberFormatter.percentAPY.stringFromDecimal($0) }

            let baseAssetPrice = prices?.first(where: { $0.priceId == baseAsset.priceId })
            let targetAssetPrice = prices?.first(where: { $0.priceId == targetAsset.priceId })
            let poolReservesInfo = reserves?.value?.first(where: { $0.poolId == pair.pairId })
            let reservesValue = modelFactory.buildReserves(
                pool: pair,
                chain: chain,
                reservesInfo: poolReservesInfo,
                baseAssetPrice: baseAssetPrice,
                targetAssetPrice: targetAssetPrice
            )
            let reservesString = reservesValue.flatMap { fiatFormatter.stringFromDecimal($0) }
            let reservesLabelText: String? = reservesString.flatMap { "\($0) TVL" }

            return LiquidityPoolListCellModel(
                tokenPairIconsVieWModel: iconsViewModel,
                tokenPairNameLabelText: tokenPairName,
                rewardTokenNameLabelText: rewardTokenNameLabelText,
                apyLabelText: apyLabelText,
                stakingStatusLabelText: nil,
                reservesLabelText: reservesLabelText,
                sortValue: reservesValue.or(.zero),
                liquidityPair: pair
            )
        }
        .sorted(by: { $0.sortValue > $1.sortValue })
        .filter {
            guard let searchText, searchText.isNotEmpty else {
                return true
            }

            return $0.tokenPairNameLabelText?.lowercased().contains(searchText.lowercased()) == true
        }

        return LiquidityPoolListViewModel(
            poolViewModels: poolViewModels,
            titleLabelText: R.string.localizable.lpAvailablePoolsTitle(preferredLanguages: locale.rLanguages),
            moreButtonVisible: type == .embed,
            backgroundVisible: type == .full,
            refreshAvailable: type == .full,
            isEmbed: type == .embed
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
