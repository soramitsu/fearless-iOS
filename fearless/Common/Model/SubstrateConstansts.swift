import Foundation
import FearlessUtils

struct SubstrateConstants {
    static let maxNominations = 16
    static let accountIdLength = 32
    static let paraIdLength = 4

    static func paraIdType(runtimeMetadata: RuntimeMetadata?) -> String {
        if let runtimeMetadata = runtimeMetadata, runtimeMetadata.version < 14 {
            return "ParaId"
        }

        // Send this by default, because mostly all networks should be on V14+,
        // so we will ignore tons of errors until runtime metadata parsed
        return "polkadot_parachain::primitives::Id"
    }

    static let maxUnbondingRequests = 32
}
