import Foundation
import SSFModels
import SSFStorageQueryKit

struct StakingErasTotalStakeRequest: SSFStorageQueryKit.PrefixRequest {
    var storagePath: any SSFModels.StorageCodingPathProtocol {
        StorageCodingPath.erasTotalStake
    }

    var keyType: SSFStorageQueryKit.MapKeyType {
        .u32
    }

    var parametersType: SSFStorageQueryKit.PrefixStorageRequestParametersType {
        .simple
    }
}
