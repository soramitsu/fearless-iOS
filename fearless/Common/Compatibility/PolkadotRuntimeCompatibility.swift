import Foundation
import SSFModels

/// Compatibility helpers tracking upstream Polkadot runtime changes that affect client behavior.
/// Context:
/// - Add foreign‑consensus cousin Asset Hub as trusted aliaser (XCMv5 origin preservation)
/// - Configure block providers for pallets requiring block context on Asset Hubs:
///   vesting: Relay chain block provider
///   multisig: Local block provider
///   proxy: Relay chain block provider
///   nfts: Relay chain block provider
enum PolkadotRuntimeCompatibility {
    enum BlockProviderHint {
        case relay
        case local
    }

    enum Pallet: String {
        case vesting
        case multisig
        case proxy
        case nfts
    }

    /// Known Asset Hub paraIds by ecosystem (well‑known 1000 across relaychains).
    /// Note: values are strings to match `ChainModel.paraId` format.
    static let assetHubParaIds: Set<String> = [
        // Polkadot Asset Hub (Statemint)
        "1000",
        // Kusama Asset Hub (Statemine)
        "1000",
        // Westend Asset Hub (Westmint), commonly 1000 as well
        "1000"
    ]

    /// Returns a hint which block provider the runtime uses for the given pallet on Asset Hub chains.
    /// This does not change on‑chain logic, but allows the app to pick appropriate time sources
    /// or show accurate user messaging when needed.
    static func blockProviderHint(for pallet: Pallet, on chain: ChainModel) -> BlockProviderHint? {
        guard let paraId = chain.paraId, assetHubParaIds.contains(paraId) else {
            return nil
        }

        switch pallet {
        case .vesting: return .relay
        case .multisig: return .local
        case .proxy: return .relay
        case .nfts: return .relay
        }
    }

    /// Whether the given chain should be considered a trusted aliaser for XCM origin preservation.
    /// Client components that build XCM paths can use this to prefer reserve transfers over teleports
    /// in cases where origin preservation is required for foreign‑consensus parachains.
    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        guard let paraId = chain.paraId else { return false }
        return assetHubParaIds.contains(paraId)
    }
}
