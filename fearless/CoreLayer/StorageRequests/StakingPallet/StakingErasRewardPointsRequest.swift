import Foundation
import SSFModels
import SSFStorageQueryKit

struct StakingErasRewardPointsRequest: SSFStorageQueryKit.PrefixRequest {
    var keyType: SSFStorageQueryKit.MapKeyType {
        .u32
    }

    var parametersType: SSFStorageQueryKit.PrefixStorageRequestParametersType {
        .simple
    }

    var storagePath: any SSFModels.StorageCodingPathProtocol {
        StorageCodingPath.erasRewardPoints
    }
}
