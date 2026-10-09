import Foundation
import SSFModels
import RobinHood

extension ChainModel {
    func replacingNodeConfiguration(
        nodes: Set<ChainNodeModel>,
        selectedNode: ChainNodeModel?,
        customNodes: Set<ChainNodeModel>?
    ) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: assets,
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: identityChain
        )
    }

    func replacingNodes(_ nodes: Set<ChainNodeModel>) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: assets,
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: identityChain
        )
    }

    func replacingDisabled(_ disabled: Bool) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: assets,
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: identityChain
        )
    }

    var isSupported: Bool {
        AppVersion.stringValue?.versionLowerThan(iosMinAppVersion) == false
    }

    var stakingSettings: ChainStakingSettings? {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .reef, .scuba:
            return ReefChainStakingSettings()
        case .soraMain:
            return SoraChainStakingSettings()
        default:
            return DefaultRelaychainChainStakingSettings()
        }
    }
}

// MARK: - Wallet connect

extension ChainModel {
    func match(_ caip2ChainId: Caip2ChainId) -> Bool {
        if isTonCompatibilityChain {
            // CAIP-2 namespace for TON is still evolving; treat as unmatched for now.
            return false
        }

        switch chainBaseType {
        case .substrate:
            let namespace = "polkadot"
            let knownChainCaip2ChainId = Caip2ChainId(
                namespace: namespace,
                reference: chainId
            )
            return knownChainCaip2ChainId.reference.hasPrefix(caip2ChainId.reference) && namespace == caip2ChainId.namespace
        case .ethereum:
            let namespace = "eip155"
            let knownChainCaip2ChainId = Caip2ChainId(
                namespace: namespace,
                reference: chainId.replacingOccurrences(of: "0x", with: "")
            )
            return caip2ChainId == knownChainCaip2ChainId
        }
    }
}

extension ChainModel {
    var isTonCompatibilityChain: Bool {
        let chainName = name.lowercased()
        let chainNameTokens = chainName.components(
            separatedBy: CharacterSet.alphanumerics.inverted
        )
        if chainNameTokens.contains("ton") {
            return true
        }

        let chainIdLowercased = chainId.lowercased()
        switch chainIdLowercased {
        case "ton",
             "-239",
             "-3",
             "ton-mainnet",
             "ton:mainnet",
             "ton-testnet",
             "ton:testnet":
            return true
        default:
            break
        }
        if chainIdLowercased.hasPrefix("ton-") || chainIdLowercased.hasPrefix("ton:") {
            return true
        }

        let nodeDomains = ["ton.org", "tonapi.io", "toncenter.com", "tonhubapi.com"]
        if nodes.contains(where: { node in
            guard let host = node.url.host?.lowercased() else {
                return false
            }
            return nodeDomains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }
        }) {
            return true
        }

        let explorerDomains = ["tonviewer.com", "tonscan.org"]
        return externalApi?.explorers?.contains(where: { explorer in
            guard let host = URL(string: explorer.url)?.host?.lowercased() else {
                return false
            }
            return explorerDomains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }
        }) == true
    }
}
