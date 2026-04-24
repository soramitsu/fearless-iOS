import Foundation
import SSFModels

enum PolkadotRuntimeCompatibility {
    // Centralized compatibility check used by cross-chain confirmation note rendering.
    // Keep behavior equivalent to prior call-site logic unless updated intentionally.
    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        chain.paraId == "1000"
    }
}
