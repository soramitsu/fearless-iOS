import Foundation
import SoraFoundation
import SSFModels

struct DappBrowsetNetworkFilterViewModel {
    let networkName: String
    let image: ImageViewModelProtocol?
}

protocol DappBrowserViewModelFactory {
    func buildViewModel(
        dapps: [DappCategory],
        connected: [TonConnectApp],
        chains: [ChainModel],
        networkFilter: NetworkManagmentFilter,
        locale: Locale,
        wallet: MetaAccountModel,
        page: DappBrowserViewControllerPage
    ) -> [DappBrowserViewModel]

    func buildNetworkFilterViewModel(
        chains: [ChainModel],
        filter: NetworkManagmentFilter,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> DappBrowsetNetworkFilterViewModel?
}

final class DappBrowserViewModelFactoryImpl: DappBrowserViewModelFactory {
    func buildViewModel(
        dapps: [DappCategory],
        connected: [TonConnectApp],
        chains: [ChainModel],
        networkFilter: NetworkManagmentFilter,
        locale: Locale,
        wallet: MetaAccountModel,
        page: DappBrowserViewControllerPage
    ) -> [DappBrowserViewModel] {
        switch page {
        case .dapps:
            return buildDappsPageViewModel(
                dapps: dapps,
                chains: chains,
                networkFilter: networkFilter,
                locale: locale,
                wallet: wallet
            )
        case .connected:
            return buildConnectedPageViewModel(
                wallet: wallet,
                connected: connected,
                locale: locale
            )
        }
    }

    func buildNetworkFilterViewModel(
        chains: [ChainModel],
        filter: NetworkManagmentFilter,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> DappBrowsetNetworkFilterViewModel? {
        switch wallet.ecosystem {
        case .regular:
            let selectedFilterName: String
            let selectedFilterImage: ImageViewModelProtocol?
            switch filter {
            case let .chain(id):
                let selectedChain = chains.first(where: { $0.chainId == id })
                selectedFilterName = selectedChain?.name ?? ""
                selectedFilterImage = selectedChain?.icon.map { RemoteImageViewModel(url: $0) }
            case .all:
                selectedFilterName = R.string.localizable.chainSelectionAllNetworks(
                    preferredLanguages: locale.rLanguages
                )
                selectedFilterImage = filter.filterImage
            case .popular:
                selectedFilterName = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages)
                selectedFilterImage = filter.filterImage
            case .favourite:
                selectedFilterName = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages)
                selectedFilterImage = filter.filterImage
            }
            return DappBrowsetNetworkFilterViewModel(
                networkName: selectedFilterName,
                image: selectedFilterImage
            )
        case .ton:
            return DappBrowsetNetworkFilterViewModel(
                networkName: "Ton Mainnet",
                image: BundleImageViewModel(image: R.image.tonIcon())
            )
        }
    }

    // MARK: - Private methods

    private func buildDappsPageViewModel(
        dapps: [DappCategory],
        chains: [ChainModel],
        networkFilter: NetworkManagmentFilter,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> [DappBrowserViewModel] {
        var viewModel: [DappBrowserViewModel] = []

        if let top = dapps.first(where: { $0.type == .top }) {
            let topViewModel = buildFeaturedViewModel(dapps: top.apps)
            viewModel.append(topViewModel)
        }

        switch networkFilter {
        case .all:
            let sections = dapps.compactMap { buildSectionViewModel(category: $0, locale: locale, maxInSection: 3) }
            viewModel.append(contentsOf: sections)
        case let .chain(chain):
            let chainApps = dapps.filter { dapp in
                dapp.apps.contains(where: { $0.chains.contains(chain) })
            }
            let sections = chainApps.compactMap { buildSectionViewModel(category: $0, locale: locale, maxInSection: 3)}
            viewModel.append(contentsOf: sections)
        case .popular:
            let popularChains = chains
                .filter { $0.rank != nil }
                .map { $0.chainId }
            let sections = buildSection(
                dapps: dapps,
                chains: popularChains,
                locale: locale,
                maxInSection: 3
            )
            viewModel.append(contentsOf: sections)
        case .favourite:
            let favourite = chains
                .filter { wallet.favouriteChainIds.contains($0.chainId) == true }
                .map { $0.chainId }
            let sections = buildSection(
                dapps: dapps,
                chains: favourite,
                locale: locale,
                maxInSection: 3
            )
            viewModel.append(contentsOf: sections)
        }

        return viewModel
    }

    private func buildConnectedPageViewModel(
        wallet: MetaAccountModel,
        connected: [TonConnectApp],
        locale: Locale
    ) -> [DappBrowserViewModel] {
        var viewModel: [DappBrowserViewModel] = []
        let walletApps = connected.filter { $0.walletId == wallet.metaId && $0.connectionType == .js }

        if walletApps.isNotEmpty {
            let apps = connected
                .filter { $0.walletId == wallet.metaId }
                .map {
                TonDapp(
                    identifier: $0.identifier,
                    chains: ["\(TonConstants.tonChainId)", "\(TonConstants.testnetChainId)"],
                    name: $0.name,
                    description: nil,
                    icon: $0.iconUrl ?? TonConstants.tonIcon,
                    background: nil,
                    url: $0.appUrl
                )
            }
            let connectedViewModel = buildSectionViewModel(
                category: .init(
                    type: .connected,
                    apps: apps
                ),
                locale: locale,
                maxInSection: .max
            )
            if let connectedViewModel {
                viewModel.append(connectedViewModel)
            }
        }
        return viewModel
    }

    private func buildSection(
        dapps: [DappCategory],
        chains: [ChainModel.Id],
        locale: Locale,
        maxInSection: Int
    ) -> [DappBrowserViewModel] {
        let apps = dapps.filter { dappCat in
            dappCat.apps.contains { dapp in
                dapp.chains.contains { chainId in
                    chains.contains(chainId)
                }
            }
        }
        let sections = apps.map { buildSectionViewModel(category: $0, locale: locale, maxInSection: maxInSection)}
        return sections.compactMap { $0 }
    }

    private func buildFeaturedViewModel(
        dapps: [TonDapp]
    ) -> DappBrowserViewModel {
        let featured = dapps.map {
            DappBrowserFeaturedViewModel(
                poster: RemoteImageViewModel(url: $0.background) ?? BundleImageViewModel(image: R.image.featuredBanner()),
                icon: RemoteImageViewModel(url: $0.icon),
                dappName: $0.name,
                dappDescription: $0.description ?? "",
                dapp: $0
            )
        }
        let viewModel = DappBrowserViewModel.featured(featured)
        return viewModel
    }

    private func buildSectionViewModel(
        category: DappCategory,
        locale: Locale,
        maxInSection: Int
    ) -> DappBrowserViewModel? {
        guard let title = getTitle(for: category.type, locale: locale) else {
            return nil
        }
        let header = DappBrowserSectionHeaderViewViewModel(
            title: title,
            isAllHidden: category.apps.count <= maxInSection
        )
        let list = category.apps.prefix(maxInSection).map {
            DappBrowserListCellViewModel(
                icon: RemoteImageViewModel(url: $0.icon),
                iconUrl: $0.icon,
                name: $0.name,
                description: $0.description,
                dapp: $0
            )
        }
        let listSection = DappBrowserViewModel.ListSection(
            header: header,
            list: list,
            dapps: category.apps
        )
        let viewModel = DappBrowserViewModel.section(listSection)
        return viewModel
    }

    private func getTitle(
        for category: DappCategoryType,
        locale: Locale
    ) -> String? {
        switch category {
        case .connected:
            return R.string.localizable.dappConnectedTitle(preferredLanguages: locale.rLanguages)
        case .featured:
            return R.string.localizable.dappCategoryFeaturedTitle(preferredLanguages: locale.rLanguages)
        case .utilities:
            return R.string.localizable.dappCategoryUtilitiesTitle(preferredLanguages: locale.rLanguages)
        case .nft:
            return R.string.localizable.dappCategoryNftTitle(preferredLanguages: locale.rLanguages)
        case .defi:
            return R.string.localizable.dappCategoryDefiTitle(preferredLanguages: locale.rLanguages)
        case .top:
            return nil
        case .explorers:
            return "Explorers"
        }
    }
}
