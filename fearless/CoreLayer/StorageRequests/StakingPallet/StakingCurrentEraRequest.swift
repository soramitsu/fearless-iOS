import Foundation
import SSFModels
import SSFUtils

struct StakingCurrentEraRequest: StorageRequest {
    var parametersType: StorageRequestParametersType {
        .simple
    }

    var storagePath: StorageCodingPath {
        .currentEra
    }
}
