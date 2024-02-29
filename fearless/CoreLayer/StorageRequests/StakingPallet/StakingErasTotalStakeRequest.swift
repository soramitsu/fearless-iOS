import Foundation
import SSFModels

struct StakingErasTotalStakeRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasTotalStake
    }

    var keyType: RuntimePrimitive {
        .u32
    }

    var parametersType: PrefixStorageRequestParametersType {
        .empty
    }
}
