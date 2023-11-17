import Foundation
import SSFModels

protocol WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedFilter: NetworkManagmentFilter,
        selectedChains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> WalletMainContainerViewModel
}

final class WalletMainContainerViewModelFactory: WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedFilter: NetworkManagmentFilter,
        selectedChains: [ChainModel],
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> WalletMainContainerViewModel {
        var selectedChain: ChainModel?
        let selectedFilterName: String
        let selectedFilterImage: ImageViewModelProtocol?
        switch selectedFilter {
        case let .chain(id):
            selectedChain = selectedChains.first(where: { $0.chainId == id })
            selectedFilterName = selectedChain?.name ?? ""
            selectedFilterImage = selectedChain?.icon.map { RemoteImageViewModel(url: $0) }
        case .all:
            selectedFilterName = R.string.localizable.chainSelectionAllNetworks(
                preferredLanguages: locale.rLanguages
            )
            selectedFilterImage = selectedFilter.filterImage
        case .popular:
            selectedFilterName = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages)
            selectedFilterImage = selectedFilter.filterImage
        case .favourite:
            selectedFilterName = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages)
            selectedFilterImage = selectedFilter.filterImage
        }

        var address: String?
        if
            let selectedChain = selectedChain,
            let chainAccountResponse = selectedMetaAccount.fetch(for: selectedChain.accountRequest()),
            let address1 = try? AddressFactory.address(for: chainAccountResponse.accountId, chain: selectedChain) {
            address = address1
        }

        let mutedIssuesChainIds = chainSettings.filter { $0.issueMuted }.map { $0.chainId }
        var hasNetworkIssues: Bool = false
        var hasAccountIssues: Bool = false
        let unusedChains = selectedMetaAccount.unusedChainIds ?? []
        chainsIssues.forEach { issue in
            switch issue {
            case let .network(chains):
                hasNetworkIssues = chains.first(where: { !mutedIssuesChainIds.contains($0.chainId) }) != nil
            case let .missingAccount(chains):
                hasAccountIssues = chains.first(where: { !unusedChains.contains($0.chainId) }) != nil
            }
        }

        let hasIssues = hasNetworkIssues || hasAccountIssues

        return WalletMainContainerViewModel(
            walletName: selectedMetaAccount.name,
            selectedFilter: selectedFilterName,
            selectedFilterImage: selectedFilterImage,
            address: address,
            hasNetworkIssues: hasIssues
        )
    }
}
