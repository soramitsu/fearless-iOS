import Foundation
import SSFModels

struct StakingErasValidatorRewardRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasValidatorReward
    }

    var keyType: RuntimePrimitive {
        .u32
    }

    var parametersType: PrefixStorageRequestParametersType {
        .empty
    }
}
