import Foundation
import SSFModels
import RobinHood

extension ChainModel: Identifiable {
    public var identifier: String { chainId }

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
