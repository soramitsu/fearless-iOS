import Foundation
import SoraFoundation
import SoraKeystore
import BigInt
import SSFModels

protocol ChainAssetListViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithMissingAccounts: [ChainModel.Id],
        shouldRunManageAssetAnimate: Bool,
        isSearch: Bool
    ) -> ChainAssetListViewModel
}

final class ChainAssetListViewModelFactory: ChainAssetListViewModelFactoryProtocol {
    internal let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithMissingAccounts: [ChainModel.Id],
        shouldRunManageAssetAnimate: Bool,
        isSearch: Bool
    ) -> ChainAssetListViewModel {
        let enabledChainAssets = enabled(chainAssets: chainAssets, for: wallet)

        let assetChainAssetsArray = createAssetChainAssets(
            from: enabledChainAssets,
            accountInfos: accountInfos,
            pricesData: prices.pricesData,
            wallet: wallet
        )

        let sortedAssetChainAssets = sortAssetList(
            wallet: wallet,
            assetChainAssetsArray: assetChainAssetsArray
        )

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = sortedAssetChainAssets.compactMap { assetChainAssets in
            let priceId = assetChainAssets.mainChainAsset.asset.priceId ?? assetChainAssets.mainChainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildChainAccountBalanceCellViewModel(
                chainAssets: assetChainAssets.chainAssets,
                chainAsset: assetChainAssets.mainChainAsset,
                priceData: priceData,
                priceDataUpdated: prices.updated,
                accountInfos: accountInfos,
                locale: locale,
                wallet: wallet,
                chainsWithMissingAccounts: chainsWithMissingAccounts
            )
        }

        let isColdBoot = chainAssetCellModels.filter { !$0.priceDataWasUpdated }.isNotEmpty
        let shouldRunManageAssetAnimate = shouldRunManageAssetAnimate && !isColdBoot

        var emptyState: ChainAssetListViewModelEmptyState?
        if chainAssetCellModels.isEmpty, isSearch {
            emptyState = .search
        } else if chainAssetCellModels.isEmpty {
            emptyState = .hidden
        }

        return ChainAssetListViewModel(
            cells: chainAssetCellModels,
            emptyState: emptyState,
            isSearch: isSearch,
            shouldRunManageAssetAnimate: shouldRunManageAssetAnimate
        )
    }

    // MARK: - Private methods

    private func buildChainAccountBalanceCellViewModel(
        chainAssets: [ChainAsset],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        priceDataUpdated: Bool,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel,
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAccountBalanceCellViewModel? {
        let priceAttributedString = getPriceAttributedString(
            priceData: priceData,
            locale: locale,
            currency: wallet.selectedCurrency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        var isColdBoot = true
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let key = chainAsset.uniqueKey(accountId: accountId)
            isColdBoot = !accountInfos.keys.contains(key)
        }
        let chainsAssetsWithBalance = chainAssets.filter { chainAsset in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getBalance(for: chainAsset, accountInfo: accountInfo) != Decimal.zero
            }
            return false
        }

        let notUtilityChainsWithBalance = chainsAssetsWithBalance.filter { $0 != chainAsset }
        let isMissingAccount = chainAssets.first(where: {
            chainsWithMissingAccounts.contains($0.chain.chainId)
                || wallet.unusedChainIds.or([]).contains($0.chain.chainId)
        }) != nil

        if
            chainsWithMissingAccounts.contains(chainAsset.chain.chainId)
            || wallet.unusedChainIds.or([]).contains(chainAsset.chain.chainId) {
            isColdBoot = !isMissingAccount
        }

        let totalAssetBalance = getBalanceString(
            for: chainAssets,
            accountInfos: accountInfos,
            locale: locale,
            wallet: wallet
        )

        let totalFiatBalance = getFiatBalanceString(
            for: chainAssets,
            accountInfos: accountInfos,
            priceData: priceData,
            locale: locale,
            wallet: wallet,
            shouldShowZero: false
        )

        var isUnused = false
        if let unusedChainIds = wallet.unusedChainIds {
            isUnused = unusedChainIds.contains(chainAsset.chain.chainId)
        }

        let shownChainAssetsIconsArray = notUtilityChainsWithBalance.map { $0.chain.icon }.filter { $0 != chainAsset.chain.icon }
        let chainImages = Array(Set(shownChainAssetsIconsArray))
            .map { $0.map { RemoteImageViewModel(url: $0) }}
            .compactMap { $0 }
        let mainChainImageUrl = chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) }

        let chainIconsViewModel = ChainCollectionViewModel(
            maxImagesCount: 5,
            chainImages: chainImages.sorted(by: { $0.url.absoluteString > $1.url.absoluteString }) + [mainChainImageUrl]
        )

        let viewModel = ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: chainAssets,
            chainIconViewViewModel: chainIconsViewModel,
            chainAsset: chainAsset,
            assetName: chainAsset.asset.name,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: (chainAsset.asset.icon ?? chainAsset.chain.icon).map { buildRemoteImageViewModel(url: $0) },
            balanceString: .init(
                value: .text(totalAssetBalance),
                isUpdated: priceDataUpdated
            ),
            priceAttributedString: .init(
                value: .attributed(priceAttributedString),
                isUpdated: priceDataUpdated
            ),
            totalAmountString: .init(
                value: .text(totalFiatBalance),
                isUpdated: priceDataUpdated
            ),
            options: options,
            isColdBoot: isColdBoot,
            priceDataWasUpdated: priceDataUpdated,
            isMissingAccount: isMissingAccount,
            isUnused: isUnused,
            locale: locale
        )

        return viewModel
    }
}

extension ChainAssetListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAssetListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
extension ChainAssetListViewModelFactory: ChainAssetListBuilder {}

extension ChainAsset {
    func defineEcosystem() -> ChainEcosystem {
        if chain.options?.contains(.ethereum) == true {
            return .ethereum
        }
        if chain.parentId == Chain.polkadot.genesisHash || chain.chainId == Chain.polkadot.genesisHash {
            return .polkadot
        }
        return .kusama
    }

    func isParentChain() -> Bool {
        chain.parentId == nil
    }
}
