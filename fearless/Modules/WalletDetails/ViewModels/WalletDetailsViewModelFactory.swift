import UIKit
import SSFUtils
import SSFModels

protocol WalletDetailsViewModelFactoryProtocol {
    func buildNormalViewModel(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        locale: Locale,
        searchText: String?
    ) -> WalletDetailsViewModel

    func buildExportViewModel(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        locale: Locale,
        searchText: String?
    ) -> WalletExportViewModel
}

class WalletDetailsViewModelFactory {
    private func buildSection(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        title: String,
        locale: Locale
    ) -> WalletDetailsSection {
        WalletDetailsSection(
            title: title,
            viewModels: chains.compactMap { chain in
                let account = flow.wallet.fetch(for: chain.accountRequest())
                let icon = chain.icon.map { RemoteImageViewModel(url: $0) }
                let address = account?.toAddress()

                return WalletDetailsCellViewModel(
                    chainImageViewModel: icon,
                    account: account,
                    chain: chain,
                    address: address,
                    accountMissing: flow.wallet.fetch(
                        for: chain.accountRequest()
                    )?.accountId == nil,
                    actionsAvailable: flow.actionsAvailable,
                    locale: locale,
                    chainUnused: (flow.wallet.unusedChainIds ?? []).contains(chain.chainId)
                )
            }
        )
    }

    private func buildSections(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        locale: Locale,
        searchText: String?
    ) -> [WalletDetailsSection] {
        let sortedChains = chains.sorted(by: { $0.name < $1.name })
        let filteredChains = sortedChains.filter { chain in
            guard let searchText = searchText, searchText.isNotEmpty else {
                return true
            }

            return chain.name.lowercased().contains(searchText.lowercased())
        }

        let emptyAccounts = filteredChains.filter {
            flow.wallet.fetch(for: $0.accountRequest()) == nil
                && !(flow.wallet.unusedChainIds ?? []).contains($0.chainId)
        }
        let nativeAccounts = filteredChains.filter {
            flow.wallet.fetch(for: $0.accountRequest())?.isChainAccount == false
                || (flow.wallet.fetch(for: $0.accountRequest()) == nil
                    && (flow.wallet.unusedChainIds ?? []).contains($0.chainId))
        }

        let customAccounts = filteredChains.filter { flow.wallet.fetch(for: $0.accountRequest())?.isChainAccount == true }

        var sections: [WalletDetailsSection] = []

        if !emptyAccounts.isEmpty {
            let customSection = buildSection(
                flow: flow,
                chains: emptyAccounts,
                title: "",
                locale: locale
            )
            sections.append(customSection)
        }

        if !customAccounts.isEmpty {
            let customSection = buildSection(
                flow: flow,
                chains: customAccounts,
                title: R.string.localizable.accountsWithChangedKey(preferredLanguages: locale.rLanguages),
                locale: locale
            )
            sections.append(customSection)
        }

        if !nativeAccounts.isEmpty {
            let nativeSection = buildSection(
                flow: flow,
                chains: nativeAccounts,
                title: R.string.localizable.accountsWithSharedSecret(preferredLanguages: locale.rLanguages),
                locale: locale
            )
            sections.append(nativeSection)
        }

        return sections
    }
}

extension WalletDetailsViewModelFactory: WalletDetailsViewModelFactoryProtocol {
    func buildNormalViewModel(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        locale: Locale,
        searchText: String?
    ) -> WalletDetailsViewModel {
        let sections = buildSections(flow: flow, chains: chains, locale: locale, searchText: searchText)
        return WalletDetailsViewModel(
            navigationTitle: R.string.localizable.commonWallet(preferredLanguages: locale.rLanguages),
            walletName: flow.wallet.name,
            sections: sections
        )
    }

    func buildExportViewModel(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        locale: Locale,
        searchText: String?
    ) -> WalletExportViewModel {
        let sections = buildSections(flow: flow, chains: chains, locale: locale, searchText: searchText)
        return WalletExportViewModel(
            navigationTitle: R.string.localizable.accountsForExport(preferredLanguages: locale.rLanguages),
            walletName: flow.wallet.name,
            sections: sections
        )
    }
}
