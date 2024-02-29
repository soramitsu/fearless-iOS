import Foundation
import SSFModels

struct StakingErasRewardPointsRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasRewardPoints
    }

    var keyType: RuntimePrimitive {
        .u32
    }

    var parametersType: PrefixStorageRequestParametersType {
        .empty
    }
}
