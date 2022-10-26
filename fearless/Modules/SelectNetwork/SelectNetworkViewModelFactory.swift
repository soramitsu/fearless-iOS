import Foundation

enum SelectNetworkItem {
    case allNetworks
    case chain(ChainModel)

    var chain: ChainModel? {
        switch self {
        case .allNetworks:
            return nil
        case let .chain(chain):
            return chain
        }
    }
}

protocol SelectNetworkViewModelFactoryProtocol {
    func buildViewModel(
        items: [SelectNetworkItem],
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        locale: Locale
    ) -> [SelectableIconDetailsListViewModel]
}

final class SelectNetworkViewModelFactory: SelectNetworkViewModelFactoryProtocol {
    func buildViewModel(
        items: [SelectNetworkItem],
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        locale: Locale
    ) -> [SelectableIconDetailsListViewModel] {
        var viewModels: [SelectableIconDetailsListViewModel] = []

        viewModels = items.filter { item in
            if case let .chain(chain) = item {
                return selectedMetaAccount.fetch(for: chain.accountRequest()) != nil
            }
            return true
        }.map { item in
            switch item {
            case .allNetworks:
                return SelectableIconDetailsListViewModel(
                    title: R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale.rLanguages),
                    subtitle: nil,
                    icon: nil,
                    isSelected: selectedChainId == nil,
                    identifier: nil
                )
            case let .chain(chain):
                let icon: ImageViewModelProtocol? = chain.icon.map { RemoteImageViewModel(url: $0) }
                let title = chain.name
                let isSelected = chain.identifier == selectedChainId

                return SelectableIconDetailsListViewModel(
                    title: title,
                    subtitle: nil,
                    icon: icon,
                    isSelected: isSelected,
                    identifier: chain.chainId
                )
            }
        }

        return viewModels
    }
}
