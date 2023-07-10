import Foundation
import SSFModels

protocol WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedChain: ChainModel?,
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> WalletMainContainerViewModel
}

final class WalletMainContainerViewModelFactory: WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedChain: ChainModel?,
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale,
        chainSettings: [ChainSettings]
    ) -> WalletMainContainerViewModel {
        let networkName = selectedChain?.name
            ?? R.string.localizable.chainSelectionAllNetworks(
                preferredLanguages: locale.rLanguages
            )

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
            selectedChainName: networkName,
            address: address,
            hasNetworkIssues: hasIssues
        )
    }
}
