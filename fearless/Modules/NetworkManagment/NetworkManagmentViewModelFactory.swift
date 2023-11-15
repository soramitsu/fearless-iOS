import Foundation
import SSFModels

protocol NetworkManagmentViewModelFactory {
    func createViewModel(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        filterSelect: NetworkManagmentSelect?,
        initialSelect: NetworkManagmentSelect,
        favouriteChainIds: [ChainModel.Id],
        includingMultiSelectRow: Bool,
        searchText: String?,
        locale: Locale
    ) -> NetworkManagmentViewModel
}

final class NetworkManagmentViewModelFactoryImpl: NetworkManagmentViewModelFactory {
    func createViewModel(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        filterSelect: NetworkManagmentSelect?,
        initialSelect: NetworkManagmentSelect,
        favouriteChainIds: [ChainModel.Id],
        includingMultiSelectRow: Bool,
        searchText: String?,
        locale: Locale
    ) -> NetworkManagmentViewModel {
        var networkItems: [NetworkManagmentItem] = []
        var filtredChains = chains
        if let searchText = searchText, searchText.isNotEmpty {
            filtredChains = chains.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        if filtredChains.isNotEmpty {
            switch filterSelect ?? initialSelect {
            case .chain, .all:
                networkItems = filtredChains
                    .sorted(by: { $0.name < $1.name })
                    .map { NetworkManagmentItem.chain($0) }
                networkItems.insert(.allItem, at: 0)
            case .favourite:
                networkItems = filtredChains
                    .filter { favouriteChainIds.contains($0.chainId) }
                    .sorted(by: { $0.name < $1.name })
                    .map { NetworkManagmentItem.chain($0) }
                if favouriteChainIds.isNotEmpty {
                    networkItems.insert(.favourite, at: 0)
                }
            case .popular:
                networkItems = filtredChains
                    .filter { $0.rank != nil }
                    .sorted(by: { $0.rank ?? 0 < $1.rank ?? 0 })
                    .map { NetworkManagmentItem.chain($0) }
                networkItems.insert(.popular, at: 0)
            }
        }

        if !includingMultiSelectRow {
            networkItems = networkItems.filter {
                switch $0 {
                case .chain: return true
                default: return false
                }
            }
        }

        let cells = networkItems.filter { item in
            if case let .chain(chain) = item {
                return wallet.fetch(for: chain.accountRequest()) != nil
            }
            return true
        }.compactMap { item in
            switch item {
            case let .chain(chain):
                return NetworkManagmentCellViewModel(
                    icon: chain.icon.map { RemoteImageViewModel(url: $0) },
                    name: chain.name,
                    isSelected: chain.chainId == initialSelect.identifier,
                    isFavourite: favouriteChainIds.contains(chain.chainId),
                    networkSelectType: .chain(chain.chainId)
                )
            case .allItem:
                return NetworkManagmentCellViewModel(
                    icon: BundleImageViewModel(image: R.image.iconNetwotkManagmentAll()),
                    name: R.string.localizable.stakingAnalyticsPeriodAll(preferredLanguages: locale.rLanguages).uppercased(),
                    isSelected: initialSelect.isAllFilter,
                    isFavourite: nil,
                    networkSelectType: .all
                )
            case .popular:
                return NetworkManagmentCellViewModel(
                    icon: BundleImageViewModel(image: R.image.iconNetwotkManagmentPopular()),
                    name: R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages).uppercased(),
                    isSelected: initialSelect.isPopularFilter,
                    isFavourite: nil,
                    networkSelectType: .popular
                )
            case .favourite:
                return NetworkManagmentCellViewModel(
                    icon: BundleImageViewModel(image: R.image.iconNetwotkManagmentFavourite()),
                    name: R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages).uppercased(),
                    isSelected: initialSelect.isFavouriteFilter,
                    isFavourite: nil,
                    networkSelectType: .favourite
                )
            }
        }

        let viewModel = NetworkManagmentViewModel(
            activeFilter: filterSelect ?? initialSelect,
            cells: cells
        )
        return viewModel
    }
}
