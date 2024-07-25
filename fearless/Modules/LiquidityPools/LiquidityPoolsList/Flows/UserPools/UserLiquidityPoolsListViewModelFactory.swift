import Foundation
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt
import SSFStorageQueryKit

protocol UserLiquidityPoolsListViewModelFactory {
    func buildViewModel(
        accountPools: [AccountPool]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel,
        type: LiquidityPoolListType,
        searchText: String?
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
        accountPools: [AccountPool]?,
        reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?,
        apyInfos: [PoolApyInfo]?,
        chain: ChainModel,
        prices: [PriceData]?,
        locale: Locale,
        wallet: MetaAccountModel,
        type: LiquidityPoolListType,
        searchText: String?
    ) -> LiquidityPoolListViewModel {
        let poolViewModels: [LiquidityPoolListCellModel]? = accountPools?.compactMap { pair in
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
            let apyInfo = apyInfos?.first(where: { $0.poolId == reservesAddress })
            let apyValue = apyInfo?.apy
            let apyLabelText = apyValue.flatMap { NumberFormatter.percentAPY.stringFromDecimal($0) }

            let baseAssetPrice = prices?.first(where: { $0.priceId == baseAsset.priceId })
            let targetAssetPrice = prices?.first(where: { $0.priceId == targetAsset.priceId })
            let poolReservesInfo = reserves?.value?.first(where: { $0.poolId == pair.poolId })
            let reservesValue = modelFactory.buildReserves(
                accountPool: pair,
                chain: chain,
                reserves: poolReservesInfo,
                baseAssetPrice: baseAssetPrice,
                targetAssetPrice: targetAssetPrice
            )
            let reservesString = reservesValue.flatMap { fiatFormatter.stringFromDecimal($0) }
            let reservesLabelText: String? = reservesString.flatMap { "\($0) TVL" }

            let numberFormatter = NumberFormatter.decimalFormatter(precision: 3, rounding: .floor)
            let baseAssetPooledText = pair.baseAssetPooled
                .flatMap {
                    numberFormatter.stringFromDecimal($0)
                }.flatMap {
                    "\($0) \(targetAsset.symbol.uppercased())"
                }

            let targetAssetPooledText = pair.targetAssetPooled
                .flatMap {
                    numberFormatter.stringFromDecimal($0)
                }.flatMap {
                    "\($0) \(targetAsset.symbol.uppercased())"
                }

            let stakingStatusLabelText: String? = baseAssetPooledText.flatMap {
                guard let targetAssetPooledText = targetAssetPooledText else {
                    return nil
                }

                return "\($0) - \(targetAssetPooledText)"
            }

            return LiquidityPoolListCellModel(
                tokenPairIconsVieWModel: iconsViewModel,
                tokenPairNameLabelText: tokenPairName,
                rewardTokenNameLabelText: rewardTokenNameLabelText,
                apyLabelText: apyLabelText,
                stakingStatusLabelText: stakingStatusLabelText,
                reservesLabelText: reservesLabelText,
                sortValue: reservesValue.or(.zero),
                liquidityPair: pair.liquidityPair
            )
        }.sorted(by: { $0.sortValue > $1.sortValue }).filter {
            guard let searchText, searchText.isNotEmpty else {
                return true
            }

            return $0.tokenPairNameLabelText?.lowercased().contains(searchText.lowercased()) == true
        }

        let filteredViewModels = type == .embed ? poolViewModels?.prefix(5).compactMap { $0 } : poolViewModels

        return LiquidityPoolListViewModel(
            poolViewModels: filteredViewModels,
            titleLabelText: R.string.localizable.lpUserPoolsTitle(preferredLanguages: locale.rLanguages),
            moreButtonVisible: type == .embed && (filteredViewModels?.count ?? 0 < accountPools?.count ?? 0),
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

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset, wallet: MetaAccountModel) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
    }
}
