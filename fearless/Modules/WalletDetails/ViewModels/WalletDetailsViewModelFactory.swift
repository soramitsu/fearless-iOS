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
    /// Account presentation only. This model is never inserted into the runtime
    /// chain registry, so an offline address does not enable network activity.
    static let offlineNexusChain = ChainModel(
        rank: nil,
        disabled: true,
        chainId: UniversalWalletRegistry.nexus.chainId,
        parentId: nil,
        paraId: nil,
        name: "SORA Nexus",
        assets: [],
        xcm: nil,
        nodes: [],
        addressPrefix: 0,
        types: nil,
        icon: UniversalWalletRegistry.tairaChainIconURL,
        options: nil,
        externalApi: nil,
        selectedNode: nil,
        customNodes: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )

    private static let offlineRestoredChains = [
        UniversalWalletRegistry.bitcoinTestnetRegistryEntry,
        UniversalWalletRegistry.solanaMainnetRegistryEntry,
        UniversalWalletRegistry.tonMainnetRegistryEntry
    ].map { entry in
        ChainModel(
            rank: nil,
            disabled: true,
            chainId: entry.chainId,
            parentId: nil,
            paraId: nil,
            name: entry.displayName,
            assets: [],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: entry.chainId == UniversalWalletRegistry.bitcoinTestnet.chainId ? [.testnet] : nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func account(for chain: ChainModel, flow: WalletDetailsFlow) -> ChainAccountResponse? {
        guard case .normal = flow,
              UniversalWalletChainAccountSupport.chainId(chain.chainId, matches: UniversalWalletRegistry.nexus.chainId)
        else {
            return flow.wallet.fetch(for: chain.accountRequest())
        }

        let dedicatedAccounts = flow.wallet.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: UniversalWalletRegistry.nexus.chainId)
        }
        // A dedicated Nexus identity takes priority. Never replace an invalid
        // existing identity with a different account's address.
        let candidate: ChainAccountModel?
        if dedicatedAccounts.isEmpty {
            candidate = flow.wallet.chainAccounts.first {
                UniversalWalletChainAccountSupport.isValidTairaAccount($0)
            }
        } else {
            candidate = dedicatedAccounts.count == 1 ? dedicatedAccounts.first : nil
        }
        guard let candidate,
              candidate.cryptoType == CryptoType.ed25519.rawValue,
              !candidate.ethereumBased,
              candidate.accountId == candidate.publicKey,
              candidate.publicKey.count == 32,
              UniversalWalletChainAccountSupport.address(
                  for: chain.chainId, publicKey: candidate.publicKey
              ) != nil else {
            return nil
        }
        // Iroha derivation is network-independent; I105 applies the Nexus
        // discriminant locally to the same wallet public key used on Taira.
        return ChainAccountResponse(
            chainId: chain.chainId,
            accountId: candidate.accountId,
            publicKey: candidate.publicKey,
            name: flow.wallet.name,
            cryptoType: .ed25519,
            addressPrefix: 0,
            isEthereumBased: false,
            isChainAccount: true,
            walletId: flow.wallet.metaId
        )
    }

    private func buildSection(
        flow: WalletDetailsFlow,
        chains: [ChainModel],
        title: String,
        locale: Locale
    ) -> WalletDetailsSection {
        WalletDetailsSection(
            title: title,
            viewModels: chains.compactMap { chain in
                let account = account(for: chain, flow: flow)
                let icon = chain.icon.map { RemoteImageViewModel(url: $0) }
                let address = account?.toAddress()

                return WalletDetailsCellViewModel(
                    chainImageViewModel: icon,
                    account: account,
                    chain: chain,
                    address: address,
                    accountMissing: account == nil,
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
            account(for: $0, flow: flow) == nil
                && !(flow.wallet.unusedChainIds ?? []).contains($0.chainId)
        }
        let nativeAccounts = filteredChains.filter {
            UniversalWalletChainAccountSupport.isUniversalWalletChain($0.chainId)
                && account(for: $0, flow: flow) != nil
                || account(for: $0, flow: flow)?.isChainAccount == false
                || (account(for: $0, flow: flow) == nil
                    && (flow.wallet.unusedChainIds ?? []).contains($0.chainId))
        }

        let customAccounts = filteredChains.filter {
            !UniversalWalletChainAccountSupport.isUniversalWalletChain($0.chainId)
                && account(for: $0, flow: flow)?.isChainAccount == true
        }

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
        var accountChains = chains.filter {
            !UniversalWalletChainAccountSupport.chainId($0.chainId, matches: UniversalWalletRegistry.nexus.chainId)
        }
        for chain in Self.offlineRestoredChains where
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(in: flow.wallet, for: chain.chainId) &&
            !chains.contains(where: {
                UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chain.chainId)
            }) {
            accountChains.append(chain)
        }
        accountChains.append(Self.offlineNexusChain)
        let sections = buildSections(flow: flow, chains: accountChains, locale: locale, searchText: searchText)
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
