import Foundation
import SSFModels

enum PolkadotRuntimeCompatibility {
    // Asset Hub destinations that act as trusted aliasers/reserves for DOT now
    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        // Heuristic: asset-hub-polkadot or ID range used by system parachains
        // Prefer explicit check on known names/ids while keeping future-proof
        let normalized = chain.name.lowercased()
        if normalized.contains("asset hub"), normalized.contains("polkadot") {
            return true
        }
        // Parachain 1000 range is common for system chains; adjust if needed
        if let paraId = chain.parachainId, [1000, 1001, 1002, 1004].contains(Int(paraId)) {
            return true
        }
        return false
    }
}
