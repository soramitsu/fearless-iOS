import Foundation
import SSFModels

struct StakingErasTotalStakeRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasTotalStake
    }

    var keyType: RuntimeType {
        .u32
    }
}
