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
        search: String?,
        lens: PortfolioLens
    ) -> ChainAssetListViewModel
}

final class ChainAssetListViewModelFactory: ChainAssetListViewModelFactoryProtocol {
    internal let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let zeroDefaults: PortfolioZeroDefaultList
    private let testnets: PortfolioTestnetChainList
    private let sendVetoedChainIds: () -> Set<ChainModel.Id>
    private let tokenCatalog: CanonicalTokenGroupCatalog

    /// - Parameter sendVetoedChainIds: read on every build, so a kill switch
    ///   that arrives while the list is open removes the network's zero row.
    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        zeroDefaults: PortfolioZeroDefaultList = .bundled,
        testnets: PortfolioTestnetChainList = .bundled,
        sendVetoedChainIds: @escaping () -> Set<ChainModel.Id> = { [] },
        tokenCatalog: CanonicalTokenGroupCatalog = .bundled
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.zeroDefaults = zeroDefaults
        self.testnets = testnets
        self.sendVetoedChainIds = sendVetoedChainIds
        self.tokenCatalog = tokenCatalog
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
        search: String?,
        lens: PortfolioLens = .token
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
        let visibility = PortfolioVisibilityContext(
            wallet: wallet,
            accountInfos: accountInfos,
            networkFilter: networkFilter,
            zeroDefaults: zeroDefaults,
            testnets: testnets,
            sendVetoedChainIds: sendVetoedChainIds()
        )
        let placements = Dictionary(
            sectionChainAssets.map { ($0.chainAssetId, visibility.placement(for: $0)) },
            uniquingKeysWith: { first, _ in first }
        )
        let enabledChainAssets = portfolioAssets(
            from: displayedChainAssets,
            placements: placements
        )

        func cell(for chainAsset: ChainAsset) -> ChainAccountBalanceCellViewModel? {
            let metadataTrust = AssetTrustResolver.metadataTrust(for: chainAsset)
            let accountInfo = wallet.fetch(for: chainAsset.chain.accountRequest()).flatMap { account in
                accountInfos[chainAsset.uniqueKey(accountId: account.accountId)] ?? nil
            }
            let value = portfolioValue(
                for: chainAsset,
                accountInfo: accountInfo,
                wallet: wallet,
                testnets: testnets
            )
            // Only counted holdings show a price: unverified, untrusted, unpriced
            // and testnet assets add no fiat.
            let priceData = value.role == .counted
                ? AssetTrustResolver.trustedPrice(for: chainAsset, currency: wallet.selectedCurrency)
                : nil

            return buildChainAccountBalanceCellViewModel(
                chainAssets: [chainAsset],
                chainAsset: chainAsset,
                value: value,
                metadataTrust: metadataTrust,
                priceData: priceData,
                accountInfos: accountInfos,
                locale: locale,
                wallet: wallet,
                chainsWithIssue: chainsWithIssue,
                displayType: displayType
            )
        }
        let chainAssetCellModels = enabledChainAssets.compactMap { cell(for: $0) }
        let networkSections = buildNetworkSections(
            cells: chainAssetCellModels,
            sectionChainAssets: sectionChainAssets,
            catalogChainAssets: chainAssets,
            accountInfos: accountInfos,
            placements: placements,
            visibility: visibility,
            wallet: wallet,
            locale: locale,
            collapseZeroNetworks: { if case .chain = networkFilter { return false }; return search?.isEmpty != false }()
        )

        // Nothing is stored for Auto assets, so "cold" means no balance has
        // arrived yet rather than no preference written.
        let isColdBoot = !accountInfos.values.contains { $0 != nil }
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
        // The header total is wallet-wide, so what it leaves out is counted over the
        // whole catalog, whatever the network filter shows.
        let exclusions = displayType == .search ? PortfolioExclusions() : portfolioTotals(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet,
            testnets: testnets
        ).exclusions
        let candidates = sectionChainAssets.map { asset -> TokenGroupChildModel in
            let info = wallet.fetch(for: asset.chain.accountRequest()).flatMap { accountInfos[asset.uniqueKey(accountId: $0.accountId)] ?? nil }
            return TokenGroupChildModel(
                chainAsset: asset,
                value: portfolioValue(for: asset, accountInfo: info, wallet: wallet, testnets: testnets),
                placement: placements[asset.chainAssetId] ?? .hidden
            )
        }
        let tokenModels = TokenGroupPortfolioBuilder(catalog: tokenCatalog).build(candidates: candidates, wallet: wallet, search: search)
        let tokenRows = tokenModels.map { model in
            TokenGroupRowViewModel(
                model: model,
                amountText: (model.amount.toString(locale: locale, minimumDigits: 0, maximumDigits: Int(model.allChildren.map { $0.chainAsset.asset.precision }.max() ?? 0)) ?? "0") + " " + model.symbol,
                fiatText: model.fiat > .zero ? fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(model.fiat) : nil
            )
        }
        let shouldCollapseZero = { if case .chain = networkFilter { return false }; return search?.isEmpty != false }()
        let zeroRows = shouldCollapseZero ? tokenRows.filter { row in
            row.model.amount == .zero && row.model.allChildren.allSatisfy {
                AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: $0.chainAsset.assetKey) == .auto
            }
        } : []
        let zeroIds = Set(zeroRows.map { $0.model.id })
        var tokenCells = Dictionary(chainAssetCellModels.map { ($0.chainAsset.assetKey, $0) }, uniquingKeysWith: { first, _ in first })
        for member in tokenModels.flatMap(\.allChildren) where tokenCells[member.chainAsset.assetKey] == nil {
            tokenCells[member.chainAsset.assetKey] = cell(for: member.chainAsset)
        }
        let isWalletEmpty = !chainAssets.contains { asset in
            let info = wallet.fetch(for: asset.chain.accountRequest()).flatMap { accountInfos[asset.uniqueKey(accountId: $0.accountId)] ?? nil }
            return portfolioValue(for: asset, accountInfo: info, wallet: wallet, testnets: testnets).isFunded
        }
        let viewModel = ChainAssetListViewModel(
            displayState: displayState,
            networkSections: networkSections,
            walletId: wallet.metaId,
            lens: lens,
            tokenRows: tokenRows.filter { !zeroIds.contains($0.model.id) },
            zeroTokenRows: zeroRows,
            tokenChildCells: tokenCells,
            usesCustomOrder: wallet.assetKeysOrder?.isEmpty == false,
            isWalletEmpty: isWalletEmpty,
            showsFundingCard: isWalletEmpty && !isColdBoot && displayType == .assetChains && shouldCollapseZero,
            canReceive: !PortfolioFundingPolicy.candidates(chainAssets, wallet: wallet, action: .receive).isEmpty,
            canBuy: !PortfolioFundingPolicy.candidates(chainAssets, wallet: wallet, action: .buy).isEmpty,
            exclusions: Self.exclusionCaptions(for: exclusions),
            hiddenFundsNotice: Self.hiddenFundsNotice(for: exclusions, walletId: wallet.metaId)
        )
        return viewModel
    }

    // MARK: - Private methods

    /// A Bitcoin, Solana or Taira row without its account: tapping it sets the account up,
    /// or explains why this wallet cannot hold one and leads to the wallet list.
    private func isAccountlessAppOwnedChain(
        _ chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> Bool {
        PortfolioVisibilityContext.lacksAppOwnedAccount(chainAsset, wallet: wallet)
    }

    private func isTaira(_ chain: ChainModel) -> Bool {
        UniversalWalletChainAccountSupport.chainId(
            chain.chainId,
            matches: UniversalWalletRegistry.taira.chainId
        )
    }

    private func portfolioAssets(
        from chainAssets: [ChainAsset],
        placements: [ChainAssetId: PortfolioPlacement]
    ) -> [ChainAsset] {
        chainAssets.filter { chainAsset in
            switch placements[chainAsset.chainAssetId] {
            case .visible:
                return true
            case .detected:
                // Unverified funds remain discoverable in a collapsed review section.
                return true
            case .hidden, .zeroCollapsed, .none:
                return false
            }
        }
        .sorted {
            ($0.chain.name, $0.asset.symbolUppercased, $0.identifier) <
                ($1.chain.name, $1.asset.symbolUppercased, $1.identifier)
        }
    }

    private func buildNetworkSections(
        cells: [ChainAccountBalanceCellViewModel],
        sectionChainAssets _: [ChainAsset],
        catalogChainAssets _: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        placements _: [ChainAssetId: PortfolioPlacement],
        visibility _: PortfolioVisibilityContext,
        wallet: MetaAccountModel,
        locale: Locale,
        collapseZeroNetworks: Bool
    ) -> [AssetNetworkSectionViewModel] {
        func value(_ cell: ChainAccountBalanceCellViewModel) -> PortfolioHoldingValue {
            let asset = cell.chainAsset
            let info = wallet.fetch(for: asset.chain.accountRequest()).flatMap {
                accountInfos[asset.uniqueKey(accountId: $0.accountId)] ?? nil
            }
            return portfolioValue(for: asset, accountInfo: info, wallet: wallet, testnets: testnets)
        }
        func ordered(_ rows: [ChainAccountBalanceCellViewModel]) -> [ChainAccountBalanceCellViewModel] {
            rows.sorted { lhs, rhs in
                let left = value(lhs), right = value(rhs)
                let leftFiat = left.role == .counted ? left.fiat : .zero
                let rightFiat = right.role == .counted ? right.fiat : .zero
                if leftFiat != rightFiat { return leftFiat > rightFiat }
                if left.isFunded != right.isFunded { return left.isFunded }
                if lhs.chainAsset.asset.isUtility != rhs.chainAsset.asset.isUtility { return lhs.chainAsset.asset.isUtility }
                return (lhs.chainAsset.asset.symbolUppercased, lhs.chainAsset.identifier) <
                    (rhs.chainAsset.asset.symbolUppercased, rhs.chainAsset.identifier)
            }
        }
        var ranked: [(Decimal, Bool, UInt16, String, [AssetNetworkSectionViewModel])] = []
        for (_, members) in Dictionary(grouping: cells, by: { $0.chainAsset.chain.chainId }) {
            guard let chain = members.first?.chainAsset.chain else { continue }
            let detected = members.filter { $0.metadataTrust.trust != .verified &&
                AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: $0.chainAsset.assetKey) == .auto
            }
            let detectedKeys = Set(detected.map { $0.chainAsset.assetKey })
            let visible = members.filter { !detectedKeys.contains($0.chainAsset.assetKey) }
            let subtotal = visible.reduce(Decimal.zero) { result, cell in
                let holding = value(cell)
                return result + (holding.role == .counted ? holding.fiat : .zero)
            }
            let sync = NetworkScanStateStore.state(for: chain, walletId: wallet.metaId).attentionText(
                now: Date(), locale: FWAppearance.portfolioListRestyled ? locale : nil
            )
            var sections: [AssetNetworkSectionViewModel] = []
            if !visible.isEmpty {
                sections.append(AssetNetworkSectionViewModel(
                    id: chain.chainId, chainId: chain.chainId, kind: .assets,
                    networkName: chain.name, ecosystemName: ecosystemName(for: chain),
                    address: UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) ??
                        wallet.fetch(for: chain.accountRequest())?.toAddress(),
                    fiatSubtotal: subtotal > .zero ? fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(subtotal) : nil,
                    syncStatus: sync, detectedCount: detected.count, rows: ordered(visible)
                ))
            }
            if !detected.isEmpty {
                sections.append(AssetNetworkSectionViewModel(
                    id: chain.chainId + ":detected", chainId: chain.chainId, kind: .detected,
                    networkName: chain.name, ecosystemName: ecosystemName(for: chain), address: nil,
                    fiatSubtotal: nil, syncStatus: sync, detectedCount: detected.count, rows: ordered(detected)
                ))
            }
            ranked.append((subtotal, visible.contains { value($0).amount > .zero }, chain.rank ?? UInt16.max, chain.name, sections))
        }
        let sorted = ranked.sorted {
            if $0.0 != $1.0 { return $0.0 > $1.0 }
            if $0.1 != $1.1 { return $0.1 && !$1.1 }
            if !$0.1, $0.2 != $1.2 { return $0.2 < $1.2 }
            return $0.3.localizedCaseInsensitiveCompare($1.3) == .orderedAscending
        }.flatMap { $0.4 }
        guard collapseZeroNetworks else { return sorted }
        let zero = sorted.filter { section in
            section.kind == .assets && section.rows.allSatisfy { cell in
                value(cell).amount == .zero && AssetVisibilityPreferenceStore.preference(
                    walletId: wallet.metaId, assetKey: cell.chainAsset.assetKey
                ) == .auto
            }
        }
        guard !zero.isEmpty else { return sorted }
        let zeroIds = Set(zero.map(\.id))
        let summaryId = "portfolio:zero-networks"
        let summary = AssetNetworkSectionViewModel(
            id: summaryId, chainId: "", kind: .zeroNetworks(count: zero.count), networkName: "",
            ecosystemName: "", address: nil, fiatSubtotal: nil, syncStatus: nil, detectedCount: 0, rows: []
        )
        return sorted.filter { !zeroIds.contains($0.id) } + [summary] + zero.map { section in
            var child = section
            child.parentSectionId = summaryId
            return child
        }
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
            if chainAssets.count == 1,
               let chainAsset = chainAssets.first,
               isAccountlessAppOwnedChain(chainAsset, wallet: wallet) {
                let chain = chainAsset.chain
                return .chainHasAccountIssue(chain: chain)
            }
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
        value: PortfolioHoldingValue,
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
        ) ?? noPriceAttributedString(for: value)
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        let chainsAssetsWithBalance = chainAssets.filter { chainAsset in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getPortfolioBalance(for: chainAsset, accountInfo: accountInfo) != Decimal.zero
            }
            return false
        }

        // The row shows the total balance (free + reserved), so staked and locked funds
        // have a row and add up to the header; Transferable follows when it differs.
        let totalAssetBalance = amountString(value.amount, locale: locale)
        let transferableAmount = amountString(value.transferable, locale: locale)
        let transferableString = transferableAmount == totalAssetBalance ? nil : String(
            format: NSLocalizedString(
                "portfolio.asset.transferable",
                value: "Transferable %@",
                comment: "Portfolio row: the part of the balance that can be sent now"
            ),
            transferableAmount ?? "0"
        )

        let totalFiatBalance = value.role == .counted && !value.fiat.isZero
            ? fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(value.fiat)
            : nil

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

        if isAccountlessAppOwnedChain(chainAsset, wallet: wallet) {
            // Account setup is actionable, not a balance request in flight.
            isColdBoot = false
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
            hideButtonIsVisible: displayType == AssetListDisplayType.chain || metadataTrust.trust != .verified,
            swipeActionsEnabled: !isAccountlessAppOwnedChain(chainAsset, wallet: wallet) &&
                wallet.fetch(for: chainAsset.chain.accountRequest()) != nil &&
                !isTaira(chainAsset.chain),
            transferableString: transferableString
        )

        return viewModel
    }

    /// The amount as rows have always shown it: three decimals, or "0".
    private func amountString(_ amount: Decimal, locale: Locale) -> String? {
        let digits = amount > 0 ? 3 : 0
        return amount.toString(locale: locale, minimumDigits: digits, maximumDigits: digits)
    }

    /// Why a row has no fiat: test tokens have no value, and a verified holding
    /// without a trusted price says so.
    private func noPriceAttributedString(for value: PortfolioHoldingValue) -> NSAttributedString? {
        let text: String
        switch value.role {
        case .testnet:
            text = NSLocalizedString(
                "portfolio.asset.testnet_no_value",
                value: "No value",
                comment: "Portfolio row of a testnet token"
            )
        case .unpriced where value.isFunded:
            text = NSLocalizedString(
                "portfolio.asset.price_unavailable",
                value: "Price unavailable",
                comment: "Portfolio row of a funded asset without a trusted price"
            )
        case .counted, .hidden, .unpriced, .unverified:
            return nil
        }

        guard let color = R.color.colorLightGray() else {
            return NSAttributedString(string: text)
        }
        return NSAttributedString(string: text, attributes: [.foregroundColor: color])
    }
}

// MARK: - What the header total leaves out

extension ChainAssetListViewModelFactory {
    /// Hides the previous version kept (4.0.4 TON wallets) on assets that now hold funds, until
    /// the user reviews them or keeps them hidden. Hides made in this version need no notice:
    /// the caption under the list labels them.
    static func hiddenFundsNotice(
        for exclusions: PortfolioExclusions,
        walletId: MetaAccountId,
        userDefaults: UserDefaults = .standard
    ) -> PortfolioHiddenFundsNotice? {
        let hiddenInPreviousVersion = AssetVisibilityPreferenceStore.hiddenInPreviousVersion(
            walletId: walletId,
            userDefaults: userDefaults
        )
        let reviewed = AssetVisibilityPreferenceStore.reviewedHiddenFunds(
            walletId: walletId,
            userDefaults: userDefaults
        )
        let assetKeys = exclusions.hiddenFundedAssetKeys.filter {
            hiddenInPreviousVersion.contains($0) && !reviewed.contains($0)
        }
        guard !assetKeys.isEmpty else {
            return nil
        }

        let format = assetKeys.count == 1
            ? NSLocalizedString(
                "portfolio.hidden_funds.title.one",
                value: "%d hidden asset holds funds",
                comment: "Notice above the portfolio"
            )
            : NSLocalizedString(
                "portfolio.hidden_funds.title.other",
                value: "%d hidden assets hold funds",
                comment: "Notice above the portfolio"
            )
        return PortfolioHiddenFundsNotice(
            assetKeys: assetKeys,
            title: String(format: format, assetKeys.count),
            message: NSLocalizedString(
                "portfolio.hidden_funds.message",
                value: "Hidden assets are not included in your total. Review them, or keep them hidden.",
                comment: "Notice above the portfolio"
            )
        )
    }

    /// The labels under the list for what the header total leaves out (portfolio
    /// contract §3 and §9), in the extension's order.
    static func exclusionCaptions(for exclusions: PortfolioExclusions) -> [PortfolioExclusionCaption] {
        [
            hiddenAssetsCaption(count: exclusions.hiddenCount),
            testnetAssetsCaption(count: exclusions.testnetCount),
            unpricedAssetsCaption(count: exclusions.unpricedCount),
            exclusions.poolStakesExcluded ? PortfolioExclusionCaption(
                kind: .poolStakes,
                text: NSLocalizedString(
                    "portfolio.exclusions.pool_stakes",
                    value: "Pool stakes not included",
                    comment: "Under the portfolio"
                )
            ) : nil
        ].compactMap { $0 }
    }

    private static func hiddenAssetsCaption(count: Int) -> PortfolioExclusionCaption? {
        guard count > 0 else {
            return nil
        }

        let format = count == 1
            ? NSLocalizedString(
                "portfolio.exclusions.hidden.one",
                value: "%d hidden asset not included · Manage",
                comment: "Under the portfolio; opens Manage assets"
            )
            : NSLocalizedString(
                "portfolio.exclusions.hidden.other",
                value: "%d hidden assets not included · Manage",
                comment: "Under the portfolio; opens Manage assets"
            )
        return PortfolioExclusionCaption(kind: .hiddenAssets, text: String(format: format, count))
    }

    private static func testnetAssetsCaption(count: Int) -> PortfolioExclusionCaption? {
        guard count > 0 else {
            return nil
        }

        let format = count == 1
            ? NSLocalizedString(
                "portfolio.exclusions.testnet.one",
                value: "%d testnet asset not included · Manage",
                comment: "Under the portfolio; opens Manage assets. Test tokens have no value"
            )
            : NSLocalizedString(
                "portfolio.exclusions.testnet.other",
                value: "%d testnet assets not included · Manage",
                comment: "Under the portfolio; opens Manage assets. Test tokens have no value"
            )
        return PortfolioExclusionCaption(kind: .testnetAssets, text: String(format: format, count))
    }

    private static func unpricedAssetsCaption(count: Int) -> PortfolioExclusionCaption? {
        guard count > 0 else {
            return nil
        }

        let format = count == 1
            ? NSLocalizedString(
                "portfolio.exclusions.unpriced.one",
                value: "%d asset without price not included",
                comment: "Under the portfolio"
            )
            : NSLocalizedString(
                "portfolio.exclusions.unpriced.other",
                value: "%d assets without price not included",
                comment: "Under the portfolio"
            )
        return PortfolioExclusionCaption(kind: .unpricedAssets, text: String(format: format, count))
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
