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
        chainsWithIssue: [ChainIssue],
        shouldRunManageAssetAnimate: Bool,
        displayType: AssetListDisplayType,
        chainSettings: [ChainSettings]
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
        chainsWithIssue: [ChainIssue],
        shouldRunManageAssetAnimate: Bool,
        displayType: AssetListDisplayType,
        chainSettings: [ChainSettings]
    ) -> ChainAssetListViewModel {
        let enabledChainAssets = enabledOrDefault(chainAssets: chainAssets, for: wallet)

        let assetChainAssetsArray = createAssetChainAssets(
            from: enabledChainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        )

        let sortedAssetChainAssets = sortAssetList(
            wallet: wallet,
            assetChainAssetsArray: assetChainAssetsArray
        )

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = sortedAssetChainAssets.compactMap { assetChainAssets in
            let priceData = assetChainAssets.mainChainAsset.asset.getPrice(for: wallet.selectedCurrency)

            return buildChainAccountBalanceCellViewModel(
                chainAssets: assetChainAssets.chainAssets,
                chainAsset: assetChainAssets.mainChainAsset,
                priceData: priceData,
                accountInfos: accountInfos,
                locale: locale,
                wallet: wallet,
                chainsWithIssue: chainsWithIssue,
                displayType: displayType
            )
        }

        let isColdBoot = wallet.assetsVisibility.isEmpty
        let shouldRunManageAssetAnimate = shouldRunManageAssetAnimate && !isColdBoot

        let displayState: AssetListState = createDisplayState(
            wallet: wallet,
            displayType: displayType,
            chainAssets: chainAssets,
            chainsWithIssue: chainsWithIssue,
            chainSettings: chainSettings,
            shouldRunManageAssetAnimate: shouldRunManageAssetAnimate,
            cells: chainAssetCellModels
        )
        let viewModel = ChainAssetListViewModel(
            displayState: displayState
        )
        return viewModel
    }

    // MARK: - Private methods

    private func createDisplayState(
        wallet: MetaAccountModel,
        displayType: AssetListDisplayType,
        chainAssets: [ChainAsset],
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings],
        shouldRunManageAssetAnimate: Bool,
        cells: [ChainAccountBalanceCellViewModel]
    ) -> AssetListState {
        switch displayType {
        case .chain:
            if cells.isEmpty {
                return .allIsHidden
            }
            guard chainAssets.count == 1, let chain = chainAssets.first?.chain else {
                return .defaultList(cells: cells, withAnimate: shouldRunManageAssetAnimate)
            }

            let hasIssuesCkeckResult = checkHasIssue(
                chain: chain,
                wallet: wallet,
                chainsWithIssue: chainsWithIssue,
                chainSettings: chainSettings
            )
            if hasIssuesCkeckResult.hasAccountIssue {
                return .chainHasAccountIssue(chain: chain)
            } else if hasIssuesCkeckResult.hasNetworkIssue {
                return .chainHasNetworkIssue(chain: chain)
            } else {
                return .defaultList(cells: cells, withAnimate: shouldRunManageAssetAnimate)
            }
        case .assetChains:
            return .defaultList(cells: cells, withAnimate: shouldRunManageAssetAnimate)
        case .search:
            return .search(cells: cells)
        }
    }

    private func buildChainAccountBalanceCellViewModel(
        chainAssets: [ChainAsset],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel,
        chainsWithIssue: [ChainIssue],
        displayType: AssetListDisplayType
    ) -> ChainAccountBalanceCellViewModel? {
        let priceAttributedString = getPriceAttributedString(
            priceData: priceData,
            locale: locale,
            currency: wallet.selectedCurrency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        let chainsAssetsWithBalance = chainAssets.filter { chainAsset in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getBalance(for: chainAsset, accountInfo: accountInfo) != Decimal.zero
            }
            return false
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

        let notUtilityChainsWithBalance = chainsAssetsWithBalance.filter { $0 != chainAsset }
        let shownChainAssetsIconsArray = notUtilityChainsWithBalance.map { $0.chain.icon }.filter { $0 != chainAsset.chain.icon }
        let chainImages = Array(Set(shownChainAssetsIconsArray))
            .map { $0.map { RemoteImageViewModel(url: $0) }}
            .compactMap { $0 }
        let mainChainImageUrl = chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) }

        let chainIconsViewModel = ChainCollectionViewModel(
            maxImagesCount: 5,
            chainImages: chainImages.sorted(by: { $0.url.absoluteString > $1.url.absoluteString }) + [mainChainImageUrl]
        )

        var isColdBoot = wallet.assetsVisibility.isEmpty
        chainsWithIssue.forEach { issue in
            switch issue {
            case .network:
                break
            case let .missingAccount(chains):
                let unusedChains = wallet.unusedChainIds ?? []
                let isMissingAccount = chains.first(where: { !unusedChains.contains($0.chainId) }) != nil
                isColdBoot = !isMissingAccount
            }
        }

        let viewModel = ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: chainAssets,
            chainIconViewViewModel: chainIconsViewModel,
            chainAsset: chainAsset,
            assetName: chainAsset.asset.name,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: (chainAsset.asset.icon ?? chainAsset.chain.icon).map { buildRemoteImageViewModel(url: $0) },
            balanceString: .init(
                value: .text(totalAssetBalance),
                isUpdated: true
            ),
            priceAttributedString: .init(
                value: .attributed(priceAttributedString),
                isUpdated: true
            ),
            totalAmountString: .init(
                value: .text(totalFiatBalance),
                isUpdated: true
            ),
            options: options,
            isColdBoot: isColdBoot,
            priceDataWasUpdated: true,
            locale: locale,
            hideButtonIsVisible: displayType == AssetListDisplayType.chain
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
