import Foundation
import SSFModels

struct StakingErasValidatorRewardRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasValidatorReward
    }

    var keyType: MapKeyType {
        .u32
    }
}
