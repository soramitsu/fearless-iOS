import Foundation
import SoraKeystore
import SSFModels

protocol AssetManagementViewModelFactory: ChainAssetListBuilder {
    func buildViewModel(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        locale: Locale,
        filter: NetworkManagmentFilter?,
        search: String?,
        pendingAccountInfoChainAssets: [ChainAssetId]
    ) -> AssetManagementViewModel

    func update(
        viewModel: AssetManagementViewModel,
        at indexPath: IndexPath,
        pendingAccountInfoChainAssets: [ChainAssetId],
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel
    ) -> AssetManagementViewModel

    func toggle(
        viewModel: AssetManagementViewModel,
        on section: Int
    ) -> AssetManagementViewModel
}

final class AssetManagementViewModelFactoryDefault: AssetManagementViewModelFactory {
    internal let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let catalog: CanonicalTokenGroupCatalog
    private let userDefaults: UserDefaults

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        catalog: CanonicalTokenGroupCatalog = .bundled,
        userDefaults: UserDefaults = .standard
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.catalog = catalog
        self.userDefaults = userDefaults
    }

    func buildViewModel(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        locale: Locale,
        filter: NetworkManagmentFilter?,
        search: String?,
        pendingAccountInfoChainAssets: [ChainAssetId]
    ) -> AssetManagementViewModel {
        var seen = Set<AssetKey>()
        let candidates = chainAssets.filter {
            !$0.chain.disabled && !(wallet.unusedChainIds ?? []).contains($0.chain.chainId) && seen.insert($0.assetKey).inserted
        }
        let displayed = filterChainAssets(with: filter, chainAssets: candidates, wallet: wallet, search: search)
        let context = PortfolioVisibilityContext(wallet: wallet, accountInfos: accountInfos, networkFilter: filter, userDefaults: userDefaults)
        let cells = candidates.map { chainAsset -> AssetManagementTableCellViewModel in
            let input = context.input(for: chainAsset)
            let account = wallet.fetch(for: chainAsset.chain.accountRequest())
            let info = account.flatMap { accountInfos[chainAsset.uniqueKey(accountId: $0.accountId)] ?? nil }
            let value = portfolioValue(for: chainAsset, accountInfo: info, wallet: wallet, userDefaults: userDefaults)
            let formatter = assetBalanceFormatterFactory.createInputFormatter(for: chainAsset.asset.displayInfo).value(for: locale)
            let amount = formatter.string(from: NSDecimalNumber(decimal: value.amount)) ?? "0"
            let hasPrice = value.role == .counted || (value.role == .hidden && AssetTrustResolver.priceTrust(for: chainAsset, currency: wallet.selectedCurrency).contributesToPortfolioTotal)
            let price = hasPrice ? fiatFormatter(for: wallet.selectedCurrency, locale: locale).stringFromDecimal(value.fiat) : nil
            let captionKey: String
            switch input.preference {
            case .auto: captionKey = info?.data.total == 0 && input.hasAccount ? "manage_assets.auto_zero" : "manage_assets.auto"
            case .shown: captionKey = "manage_assets.shown"
            case .hidden: captionKey = "manage_assets.hidden"
            }
            return AssetManagementTableCellViewModel(
                chainAsset: chainAsset, assetImage: chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
                assetName: chainAsset.asset.symbolUppercased, chainName: chainAsset.chain.name,
                balance: BalanceViewModel(amount: amount, price: price), decimalPrice: value.fiat,
                hidden: PortfolioVisibilityPolicy.placement(input) != .visible, hasGroup: false,
                isLoadingBalance: pendingAccountInfoChainAssets.contains(chainAsset.chainAssetId),
                preference: input.preference, preferenceCaption: PortfolioStrings.text(captionKey, locale: locale),
                amount: value.amount, valueRole: value.role
            )
        }
        // Group actions retain the complete approved membership even when a search
        // or visibility filter exposes only one child.
        let displayedKeys = Set(displayed.map(\.assetKey))
        let sections = groupedSections(cells: cells, wallet: wallet, locale: locale).compactMap { section -> AssetManagementTableSection? in
            var section = section
            section.cells = section.cells.filter { displayedKeys.contains($0.chainAsset.assetKey) }
            return section.cells.isEmpty ? nil : section
        }
        return AssetManagementViewModel(
            list: sections, filterButtonTitle: createFilterButtonTitle(filter: filter, chainAssets: candidates, locale: locale),
            addAssetButtonIsHidden: true, dispayedChainAssets: displayed,
            allChainAssets: candidates, networkFilter: filter, search: search,
            canResetOrder: wallet.assetKeysOrder != nil
        )
    }

    // Visibility is derived again after each save or balance update. Never toggle an
    // old display model: a second balance callback must not reverse the user's choice.
    func update(
        viewModel: AssetManagementViewModel,
        at _: IndexPath,
        pendingAccountInfoChainAssets: [ChainAssetId],
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel
    ) -> AssetManagementViewModel {
        var updated = buildViewModel(
            chainAssets: viewModel.allChainAssets.isEmpty ? viewModel.dispayedChainAssets : viewModel.allChainAssets,
            accountInfos: accountInfos, wallet: wallet, locale: locale, filter: viewModel.networkFilter,
            search: viewModel.search, pendingAccountInfoChainAssets: pendingAccountInfoChainAssets
        )
        let expanded = Set(viewModel.list.filter(\.isExpanded).map(\.id))
        for index in updated.list.indices { updated.list[index].isExpanded = expanded.contains(updated.list[index].id) }
        return updated
    }

    func toggle(viewModel: AssetManagementViewModel, on section: Int) -> AssetManagementViewModel {
        var updated = viewModel
        guard updated.list.indices.contains(section), updated.list[section].hasView else { return updated }
        updated.list[section].isExpanded.toggle()
        return updated
    }

    /// Manage includes hidden members so every stored choice remains reachable. It
    /// groups only exact approved identities and keeps testnets/unverified separate.
    private func groupedSections(
        cells: [AssetManagementTableCellViewModel], wallet: MetaAccountModel, locale: Locale
    ) -> [AssetManagementTableSection] {
        let eligibleGroups = Dictionary(grouping: cells.filter { cell in
            cell.valueRole != .testnet && cell.valueRole != .unverified &&
                wallet.fetch(for: cell.chainAsset.chain.accountRequest()) != nil &&
                !PortfolioVisibilityContext.lacksAppOwnedAccount(cell.chainAsset, wallet: wallet) &&
                catalog.group(for: cell.chainAsset) != nil
        }, by: { catalog.group(for: $0.chainAsset)?.id ?? "" }).filter { $0.value.count >= 2 }
        var buckets: [String: [AssetManagementTableCellViewModel]] = [:]
        for cell in cells {
            let id: String
            if cell.valueRole == .testnet { id = "testnets" }
            else if cell.valueRole == .unverified { id = "unverified" }
            else if let group = catalog.group(for: cell.chainAsset),
                    eligibleGroups[group.id]?.contains(where: { $0.chainAsset.assetKey == cell.chainAsset.assetKey }) == true {
                id = "group:" + group.id
            } else { id = "asset:" + cell.chainAsset.identifier }
            buckets[id, default: []].append(cell)
        }
        return buckets.map { id, members in
            let grouped = !id.hasPrefix("asset:")
            let sorted = members.sorted {
                if $0.decimalPrice != $1.decimalPrice { return $0.decimalPrice > $1.decimalPrice }
                return ($0.chainName, $0.chainAsset.identifier) < ($1.chainName, $1.chainAsset.identifier)
            }.map { cell -> AssetManagementTableCellViewModel in
                var row = cell; row.hasGroup = grouped; return row
            }
            let first = sorted[0]
            let title: String
            let caption: String?
            if id == "testnets" {
                title = PortfolioStrings.text("manage_assets.testnets", locale: locale)
                caption = PortfolioStrings.text("manage_assets.testnets_caption", locale: locale)
            } else if id == "unverified" {
                title = PortfolioStrings.text("manage_assets.unverified", locale: locale)
                caption = PortfolioStrings.text("manage_assets.unverified_caption", locale: locale)
            } else {
                title = catalog.group(for: first.chainAsset)?.symbol ?? first.assetName
                caption = grouped ? String(
                    format: PortfolioStrings.text("portfolio.network_count", locale: locale),
                    locale: locale,
                    Set(sorted.map { $0.chainAsset.chain.chainId }).count
                ) : nil
            }
            return AssetManagementTableSection(
                hasView: grouped, assetImage: (id == "testnets" || id == "unverified") ? nil : first.assetImage,
                assetName: title, assetCount: caption, isExpanded: false, cells: sorted,
                isAllDisabled: sorted.allSatisfy(\.hidden),
                totalBalance: id.hasPrefix("asset:") || id.hasPrefix("group:") ? sorted.reduce(.zero) { $0 + $1.amount } : .zero,
                totalFiatBalance: sorted.reduce(.zero) { $0 + $1.decimalPrice },
                rank: sorted.compactMap { $0.chainAsset.chain.rank }.min() ?? .max, id: id,
                visibilityMembers: sorted.map(\.chainAsset),
                groupVisibility: sorted.allSatisfy(\.hidden) ? .off : (sorted.allSatisfy { !$0.hidden } ? .on : .mixed)
            )
        }.sorted {
            let leftTrailing = $0.id == "testnets" ? 2 : ($0.id == "unverified" ? 1 : 0)
            let rightTrailing = $1.id == "testnets" ? 2 : ($1.id == "unverified" ? 1 : 0)
            if leftTrailing != rightTrailing { return leftTrailing < rightTrailing }
            if $0.totalFiatBalance != $1.totalFiatBalance { return $0.totalFiatBalance > $1.totalFiatBalance }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            let nameComparison = ($0.assetName ?? "").localizedCaseInsensitiveCompare($1.assetName ?? "")
            return nameComparison == .orderedSame ? $0.id < $1.id : nameComparison == .orderedAscending
        }
    }

    private func createFilterButtonTitle(
        filter: NetworkManagmentFilter?,
        chainAssets: [ChainAsset],
        locale: Locale
    ) -> String {
        let selectedFilterName: String
        switch filter {
        case let .chain(id):
            let selectedChain = chainAssets.first(where: { $0.chain.chainId == id })
            selectedFilterName = selectedChain?.chain.name ?? ""
        case .all, .none:
            selectedFilterName = R.string.localizable.chainSelectionAllNetworks(
                preferredLanguages: locale.rLanguages
            )
        case .popular:
            selectedFilterName = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages)
        case .favourite:
            selectedFilterName = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages)
        }

        return selectedFilterName
    }
}
