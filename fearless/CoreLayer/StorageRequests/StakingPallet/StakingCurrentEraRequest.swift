import Foundation
import SSFModels
import SSFUtils

struct StakingCurrentEraRequest: StorageRequest {
    typealias K = Data

    var parametersType: StorageRequestParametersType<Data> {
        .keys {
            [try StorageKeyFactory().currentEra()]
        }
    }

    var storagePath: StorageCodingPath {
        .currentEra
    }

    var responseType: StorageResponseType {
        .single
    }
}
