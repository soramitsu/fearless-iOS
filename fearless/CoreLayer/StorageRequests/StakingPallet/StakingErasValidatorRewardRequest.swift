import Foundation
import SSFModels
import SSFStorageQueryKit

struct StakingErasValidatorRewardRequest: SSFStorageQueryKit.PrefixRequest {
    var keyType: SSFStorageQueryKit.MapKeyType {
        .u32
    }

    var parametersType: SSFStorageQueryKit.PrefixStorageRequestParametersType {
        .simple
    }

    var storagePath: any SSFModels.StorageCodingPathProtocol {
        StorageCodingPath.erasValidatorReward
    }
}
