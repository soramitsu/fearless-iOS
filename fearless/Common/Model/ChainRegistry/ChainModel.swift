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

// MARK: - Polkadot Runtime Compatibility (in-target shim)

enum PolkadotRuntimeCompatibility {
    enum BlockProviderHint { case relay, local }
    enum Pallet { case vesting, multisig, proxy, nfts }

    static let assetHubParaIds: Set<String> = ["1000"]

    static func blockProviderHint(for pallet: Pallet, on chain: ChainModel) -> BlockProviderHint? {
        guard let paraId = chain.paraId, assetHubParaIds.contains(paraId) else { return nil }
        switch pallet {
        case .vesting: return .relay
        case .multisig: return .local
        case .proxy: return .relay
        case .nfts: return .relay
        }
    }

    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        guard let paraId = chain.paraId else { return false }
        return assetHubParaIds.contains(paraId)
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
