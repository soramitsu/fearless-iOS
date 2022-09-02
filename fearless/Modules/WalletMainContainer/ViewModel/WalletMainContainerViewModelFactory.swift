import Foundation

protocol WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedChain: ChainModel?,
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale
    ) -> WalletMainContainerViewModel
}

final class WalletMainContainerViewModelFactory: WalletMainContainerViewModelFactoryProtocol {
    func buildViewModel(
        selectedChain: ChainModel?,
        selectedMetaAccount: MetaAccountModel,
        chainsIssues: [ChainIssue],
        locale: Locale
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

        return WalletMainContainerViewModel(
            walletName: selectedMetaAccount.name,
            selectedChainName: networkName,
            address: address,
            hasNetworkIssues: chainsIssues.isNotEmpty
        )
    }
}
