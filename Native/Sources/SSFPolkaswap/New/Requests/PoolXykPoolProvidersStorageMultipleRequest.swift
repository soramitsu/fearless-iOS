import Foundation
import SSFModels
import SSFStorageQueryKit

struct PoolXykPoolProvidersStorageRequestParameter {
    let reservesId: Data
    let accountId: Data
}

struct PoolXykPoolProvidersStorageMultipleRequest: MultipleRequest {
    let parameters: [PoolProvidersStorageKey]

    var keyType: SSFStorageQueryKit.MapKeyType {
        .poolProvidersKey
    }
    
    var parametersType: SSFStorageQueryKit.MultipleStorageRequestParametersType {
        let params = parameters.compactMap {
            [
                [NMapKeyParam(value: $0.reservesId)],
                [NMapKeyParam(value: $0.accountId)]
            ]
        }
        return .multipleNMap(params: params)
    }
    
    var storagePath: any SSFModels.StorageCodingPathProtocol {
        return SSFPolkaswap.StorageCodingPath.poolProviders
    }
    
    
}
