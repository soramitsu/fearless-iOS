import Foundation

protocol SelectNetworkViewModelFactoryProtocol {
    func buildViewModel(
        chains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        locale: Locale
    ) -> [SelectableIconDetailsListViewModel]
}

final class SelectNetworkViewModelFactory: SelectNetworkViewModelFactoryProtocol {
    func buildViewModel(
        chains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        locale: Locale
    ) -> [SelectableIconDetailsListViewModel] {
        var viewModels: [SelectableIconDetailsListViewModel] = []

        viewModels = chains.filter { selectedMetaAccount.fetch(for: $0.accountRequest()) != nil }.map { chain in
            let icon: ImageViewModelProtocol? = chain.icon.map { RemoteImageViewModel(url: $0) }
            let title = chain.name
            let isSelected = chain.identifier == selectedChainId

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: nil,
                icon: icon,
                isSelected: isSelected
            )
        }

        let allNetworksViewModel = SelectableIconDetailsListViewModel(
            title: R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale.rLanguages),
            subtitle: nil,
            icon: nil,
            isSelected: selectedChainId == nil
        )
        viewModels.insert(allNetworksViewModel, at: 0)

        return viewModels
    }
}
