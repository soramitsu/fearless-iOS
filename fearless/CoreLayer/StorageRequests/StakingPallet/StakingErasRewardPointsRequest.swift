import Foundation
import SSFModels

struct StakingErasRewardPointsRequest: PrefixRequest {
    var storagePath: StorageCodingPath {
        .erasRewardPoints
    }

    var keyType: RuntimeType {
        .u32
    }
}
