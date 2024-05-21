import Foundation
import SoraKeystore
import SSFModels

protocol AssetManagementViewModelFactory: ChainAssetListBuilder {
    func buildViewModel(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: [PriceData],
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
        prices: [PriceData],
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

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: [PriceData],
        wallet: MetaAccountModel,
        locale: Locale,
        filter: NetworkManagmentFilter?,
        search: String?,
        pendingAccountInfoChainAssets: [ChainAssetId]
    ) -> AssetManagementViewModel {
        let filtredChainAssets = filterChainAssets(
            with: filter,
            chainAssets: chainAssets,
            wallet: wallet,
            search: search
        )
        let sectionsChunks = createAssetChainAssets(
            from: filtredChainAssets,
            accountInfos: accountInfos,
            pricesData: prices,
            wallet: wallet
        )

        let sections = sectionsChunks.map { junk in
            let hasView = junk.chainAssets.count > 1

            let cells = createCells(
                for: junk,
                wallet: wallet,
                accountInfos: accountInfos,
                locale: locale,
                prices: prices,
                hasGroup: hasView,
                pendingAccountInfoChainAssets: pendingAccountInfoChainAssets
            )

            let assetImage = junk.mainChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) }
            let assetCount = "\(junk.chainAssets.count) "
            let networksStub = R.string.localizable.connectionManagementTitle(preferredLanguages: locale.rLanguages).lowercased()
            let isAllDisabled = cells.filter { $0.hidden }.count == cells.count
            let sortedCells = sort(cells)

            let section = AssetManagementTableSection(
                hasView: hasView,
                assetImage: assetImage,
                assetName: junk.mainChainAsset.asset.name.capitalized,
                assetCount: assetCount + networksStub,
                isExpanded: false,
                cells: sortedCells,
                isAllDisabled: isAllDisabled,
                totalBalance: junk.totalBalance,
                totalFiatBalance: junk.totalFiatBalance,
                rank: junk.mainChainAsset.chain.rank.or(.max)
            )
            return section
        }

        let filterButtonTitle = createFilterButtonTitle(
            filter: filter,
            chainAssets: chainAssets,
            locale: locale
        )

        let list = sort(sections)
        let viewModel = AssetManagementViewModel(
            list: list,
            filterButtonTitle: filterButtonTitle,
            addAssetButtonIsHidden: true
        )
        return viewModel
    }

    func update(
        viewModel: AssetManagementViewModel,
        at indexPath: IndexPath,
        pendingAccountInfoChainAssets: [ChainAssetId],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: [PriceData],
        locale: Locale,
        wallet: MetaAccountModel
    ) -> AssetManagementViewModel {
        var viewModel = viewModel
        viewModel.list[indexPath.section].cells[indexPath.row].hidden.toggle()

        let section = viewModel.list[indexPath.section]
        let isAllDisabled = section.cells.filter { $0.hidden }.count == section.cells.count
        viewModel.list[indexPath.section].isAllDisabled = isAllDisabled

        if let cell = section.cells[safe: indexPath.row] {
            let isLoadingBalance = pendingAccountInfoChainAssets.contains(cell.chainAsset.chainAssetId)
            let updatedCell = update(
                accountInfos: accountInfos,
                in: cell,
                locale: locale,
                wallet: wallet,
                prices: prices,
                isLoadingBalance: isLoadingBalance
            )
            viewModel.list[indexPath.section].cells[indexPath.row] = updatedCell
        }

        return viewModel
    }

    func toggle(
        viewModel: AssetManagementViewModel,
        on section: Int
    ) -> AssetManagementViewModel {
        var viewModel = viewModel
        viewModel.list[section].isExpanded.toggle()
        return viewModel
    }

    // MARK: - Private methods

    private func update(
        accountInfos: [ChainAssetKey: AccountInfo?],
        in cell: AssetManagementTableCellViewModel,
        locale: Locale,
        wallet: MetaAccountModel,
        prices: [PriceData],
        isLoadingBalance: Bool
    ) -> AssetManagementTableCellViewModel {
        let amount = getBalanceString(
            for: [cell.chainAsset],
            accountInfos: accountInfos,
            locale: locale,
            wallet: wallet
        ) ?? "0"
        let price = getFiatBalanceString(
            for: [cell.chainAsset],
            accountInfos: accountInfos,
            priceData: prices.first(where: { $0.priceId == cell.chainAsset.asset.priceId }),
            locale: locale,
            wallet: wallet,
            shouldShowZero: true
        )
        let decimalPrice = getTotalFiatBalance(
            for: [cell.chainAsset],
            accountInfos: accountInfos,
            priceData: prices.first(where: { $0.priceId == cell.chainAsset.asset.priceId }),
            wallet: wallet
        )
        let balance = BalanceViewModel(
            amount: amount,
            price: price
        )

        var cell = cell
        cell.balance = balance
        cell.decimalPrice = decimalPrice
        cell.isLoadingBalance = isLoadingBalance
        return cell
    }

    private func createCells(
        for junk: AssetChainAssets,
        wallet: MetaAccountModel,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        prices: [PriceData],
        hasGroup: Bool,
        pendingAccountInfoChainAssets: [ChainAssetId]
    ) -> [AssetManagementTableCellViewModel] {
        let cells = junk.chainAssets.map { chainAsset in
            let amount = getBalanceString(
                for: [chainAsset],
                accountInfos: accountInfos,
                locale: locale,
                wallet: wallet
            ) ?? "0"
            let price = getFiatBalanceString(
                for: [chainAsset],
                accountInfos: accountInfos,
                priceData: prices.first(where: { $0.priceId == chainAsset.asset.priceId }),
                locale: locale,
                wallet: wallet,
                shouldShowZero: true
            )
            let decimalPrice = getTotalFiatBalance(
                for: [chainAsset],
                accountInfos: accountInfos,
                priceData: prices.first(where: { $0.priceId == chainAsset.asset.priceId }),
                wallet: wallet
            )
            let balance = BalanceViewModel(
                amount: amount,
                price: price
            )
            let hidden = checkAssetIsHidden(
                wallet: wallet,
                chainAsset: chainAsset
            )
            let isLoadingBalance = pendingAccountInfoChainAssets.contains(chainAsset.chainAssetId)
            let cell = AssetManagementTableCellViewModel(
                chainAsset: chainAsset,
                assetImage: chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
                assetName: chainAsset.asset.symbolUppercased,
                chainName: chainAsset.chain.name,
                balance: balance,
                decimalPrice: decimalPrice,
                hidden: hidden,
                hasGroup: hasGroup,
                isLoadingBalance: isLoadingBalance
            )
            return cell
        }
        return cells
    }

    private func sort(_ sections: [AssetManagementTableSection]) -> [AssetManagementTableSection] {
        sections.sorted { section1, section2 in
            (
                section1.isAllDisabled.inverted().intValue,
                section1.totalFiatBalance,
                section1.totalBalance,
                section2.rank,
                section1.assetName ?? section1.cells.first?.assetName ?? ""
            ) > (
                section2.isAllDisabled.inverted().intValue,
                section2.totalFiatBalance,
                section2.totalBalance,
                section1.rank,
                section2.assetName ?? section2.cells.first?.assetName ?? ""
            )
        }
    }

    private func sort(_ cells: [AssetManagementTableCellViewModel]) -> [AssetManagementTableCellViewModel] {
        cells.sorted { cell1, cell2 in
            (
                cell1.hidden.inverted().intValue,
                cell1.decimalPrice
            ) > (
                cell2.hidden.inverted().intValue,
                cell2.decimalPrice
            )
        }
    }

    private func checkAssetIsHidden(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> Bool {
        let isHidden = wallet.assetsVisibility.contains(where: {
            $0.assetId == chainAsset.identifier && $0.hidden
        })
        return isHidden
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
