import Foundation
import SSFModels
import RobinHood

extension ChainModel {
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

private extension ChainModel {
    var isTonCompatibilityChain: Bool {
        let chainName = name.lowercased()
        if chainName == "ton" || chainName.contains("ton ") || chainName.contains(" ton") {
            return true
        }

        let chainIdLowercased = chainId.lowercased()
        if chainIdLowercased == "ton" || chainIdLowercased.contains("ton-") {
            return true
        }

        if nodes.contains(where: { $0.url.absoluteString.lowercased().contains("ton") }) {
            return true
        }

        return externalApi?.explorers?.contains(where: { $0.url.lowercased().contains("tonviewer") }) == true
    }
}
