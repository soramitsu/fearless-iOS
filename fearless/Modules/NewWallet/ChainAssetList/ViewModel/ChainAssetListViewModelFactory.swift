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
        chainSettings: [ChainSettings],
        networkFilter: NetworkManagmentFilter?,
        search: String?
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
        chainSettings: [ChainSettings],
        networkFilter: NetworkManagmentFilter?,
        search: String?
    ) -> ChainAssetListViewModel {
        let displayedChainAssets = filterChainAssets(
            with: networkFilter,
            chainAssets: chainAssets,
            wallet: wallet,
            search: search
        )
        let sectionChainAssets = filterChainAssets(
            with: networkFilter,
            chainAssets: chainAssets,
            wallet: wallet,
            search: nil
        )
        let enabledChainAssets = portfolioAssets(
            from: displayedChainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        )

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = enabledChainAssets.compactMap { chainAsset in
            let metadataTrust = AssetTrustResolver.metadataTrust(for: chainAsset)
            let priceData = metadataTrust.trust == .verified
                ? chainAsset.asset.getPrice(for: wallet.selectedCurrency)
                : nil

            return buildChainAccountBalanceCellViewModel(
                chainAssets: [chainAsset],
                chainAsset: chainAsset,
                metadataTrust: metadataTrust,
                priceData: priceData,
                accountInfos: accountInfos,
                locale: locale,
                wallet: wallet,
                chainsWithIssue: chainsWithIssue,
                displayType: displayType
            )
        }
        let networkSections = buildNetworkSections(
            cells: chainAssetCellModels,
            sectionChainAssets: sectionChainAssets,
            catalogChainAssets: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet,
            locale: locale
        )

        let isColdBoot = chainAssets.allSatisfy {
            AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: $0.assetKey
            ) == .auto
        }
        let shouldRunManageAssetAnimate = shouldRunManageAssetAnimate && !isColdBoot

        let displayState: AssetListState = createDisplayState(
            wallet: wallet,
            displayType: displayType,
            chainAssets: displayedChainAssets,
            chainsWithIssue: chainsWithIssue,
            chainSettings: chainSettings,
            shouldRunManageAssetAnimate: shouldRunManageAssetAnimate,
            cells: chainAssetCellModels
        )
        let viewModel = ChainAssetListViewModel(
            displayState: displayState,
            networkSections: networkSections
        )
        return viewModel
    }

    // MARK: - Private methods

    private func portfolioAssets(
        from chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel
    ) -> [ChainAsset] {
        chainAssets.filter { chainAsset in
            let preference = AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey
            )
            guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
                  preference != .hidden else {
                return false
            }

            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] ?? nil
            let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
            let isPinnedDefault = chainAsset.asset.isUtility && (
                chainAsset.chain.rank != nil ||
                    wallet.favouriteChainIds.contains(chainAsset.chain.chainId)
            )
            let isShadowedDetection = MultiChainFeaturePolicy.current.assetDiscoveryShadowMode &&
                preference == .auto &&
                AssetTrustResolver.metadataTrust(for: chainAsset).trust != .verified

            guard !isShadowedDetection else {
                return false
            }

            return balance > .zero || isPinnedDefault
        }
        .sorted {
            ($0.chain.name, $0.asset.symbolUppercased, $0.identifier) <
                ($1.chain.name, $1.asset.symbolUppercased, $1.identifier)
        }
    }

    private func buildNetworkSections(
        cells: [ChainAccountBalanceCellViewModel],
        sectionChainAssets: [ChainAsset],
        catalogChainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        locale: Locale
    ) -> [AssetNetworkSectionViewModel] {
        let groupedCells = Dictionary(grouping: cells) { $0.chainAsset.chain.chainId }
        let catalogByChain = Dictionary(grouping: catalogChainAssets) { $0.chain.chainId }
        let sectionAssetsByChain = Dictionary(grouping: sectionChainAssets) { $0.chain.chainId }

        return sectionAssetsByChain.compactMap { chainId, sectionAssets -> (Bool, Decimal, String, [AssetNetworkSectionViewModel])? in
            guard let chain = sectionAssets.first?.chain else {
                return nil
            }

            let cells = groupedCells[chainId] ?? []
            let detectedCells = cells.filter { cell in
                guard cell.metadataTrust.trust != .verified else {
                    return false
                }

                return AssetVisibilityPreferenceStore.preference(
                    walletId: wallet.metaId,
                    assetKey: cell.chainAsset.assetKey
                ) == .auto
            }
            let detectedAssetKeys = Set(detectedCells.map { $0.chainAsset.assetKey })
            let visibleCells = cells.filter { !detectedAssetKeys.contains($0.chainAsset.assetKey) }
            let hasPositiveHolding = (catalogByChain[chainId] ?? []).contains { chainAsset in
                let accountInfo = wallet.fetch(for: chain.accountRequest()).flatMap { account in
                    accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] ?? nil
                }
                return getBalance(for: chainAsset, accountInfo: accountInfo) > .zero
            }
            let hasPinnedDefault = sectionAssets.contains {
                $0.asset.isUtility && (
                    $0.chain.rank != nil ||
                        wallet.favouriteChainIds.contains($0.chain.chainId)
                )
            }

            guard cells.isNotEmpty || hasPositiveHolding || hasPinnedDefault else {
                return nil
            }
            let subtotal = (catalogByChain[chainId] ?? []).reduce(Decimal.zero) { result, chainAsset in
                guard AssetTrustResolver.metadataTrust(for: chainAsset).trust == .verified else {
                    return result
                }
                let accountInfo = wallet.fetch(for: chain.accountRequest()).flatMap { account in
                    accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] ?? nil
                }
                guard getBalance(for: chainAsset, accountInfo: accountInfo) > .zero else {
                    return result
                }
                guard AssetTrustResolver.priceTrust(
                    for: chainAsset,
                    currency: wallet.selectedCurrency
                ).contributesToPortfolioTotal else {
                    return result
                }
                return result + getFiatBalance(
                    for: chainAsset,
                    accountInfo: accountInfo,
                    priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency)
                )
            }
            let formattedSubtotal = subtotal > .zero
                ? fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(subtotal)
                : nil
            let scanState = NetworkScanStateStore.state(for: chain, walletId: wallet.metaId)
            let mainSection = AssetNetworkSectionViewModel(
                id: chain.chainId,
                chainId: chain.chainId,
                kind: .assets,
                networkName: chain.name,
                ecosystemName: ecosystemName(for: chain),
                address: wallet.fetch(for: chain.accountRequest())?.toAddress(),
                fiatSubtotal: formattedSubtotal,
                syncStatus: scanState.displayText,
                detectedCount: detectedCells.count,
                rows: visibleCells.sorted {
                    ($0.chainAsset.asset.symbolUppercased, $0.chainAsset.identifier) <
                        ($1.chainAsset.asset.symbolUppercased, $1.chainAsset.identifier)
                }
            )
            let detectedSection = detectedCells.isEmpty ? nil : AssetNetworkSectionViewModel(
                id: [chain.chainId, "detected"].joined(separator: ":"),
                chainId: chain.chainId,
                kind: .detected,
                networkName: chain.name,
                ecosystemName: ecosystemName(for: chain),
                address: nil,
                fiatSubtotal: nil,
                syncStatus: scanState.displayText,
                detectedCount: detectedCells.count,
                rows: detectedCells.sorted {
                    ($0.chainAsset.asset.symbolUppercased, $0.chainAsset.identifier) <
                        ($1.chainAsset.asset.symbolUppercased, $1.chainAsset.identifier)
                }
            )
            return (subtotal > .zero, subtotal, chain.name, [mainSection, detectedSection].compactMap { $0 })
        }
        .sorted { lhs, rhs in
            if lhs.0 != rhs.0 {
                return lhs.0 && !rhs.0
            }
            if lhs.0, lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }

            return lhs.2.localizedCaseInsensitiveCompare(rhs.2) == .orderedAscending
        }
        .flatMap { $0.3 }
    }

    private func ecosystemName(for chain: ChainModel) -> String {
        let chainId = chain.chainId.lowercased()

        if chain.isTonCompatibilityChain || chainId.hasPrefix("ton:") {
            return "TON"
        } else if chainId.hasPrefix("bitcoin:") {
            return "Bitcoin"
        } else if chainId.hasPrefix("solana:") {
            return "Solana"
        } else if chainId.hasPrefix("iroha") || chainId.hasPrefix("sora:nexus") {
            return "Iroha"
        } else if chain.isEthereumBased {
            return "EVM"
        } else {
            return "Substrate"
        }
    }

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
        metadataTrust: AssetMetadataTrustInfo,
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
            locale: locale,
            wallet: wallet,
            shouldShowZero: false
        )

        var haveBalance: Bool = false
        chainAssets.forEach { chainAsset in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               accountInfos[chainAsset.uniqueKey(accountId: accountId)] != nil {
                haveBalance = true
            }
        }

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

        var isColdBoot = !haveBalance
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
            metadataTrust: metadataTrust,
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
            locale: locale,
            hideButtonIsVisible: displayType == AssetListDisplayType.chain || metadataTrust.trust != .verified
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
