import Foundation
import SSFStorageQueryKit
import SSFModels

struct PoolXykReservesStorageRequest: MultipleRequest {
    let pairs: [AssetIdPair]

    var keyType: SSFStorageQueryKit.MapKeyType {
        .assetIds
    }
    
    var parametersType: SSFStorageQueryKit.MultipleStorageRequestParametersType {
        let params = pairs.compactMap {
            [
                [NMapKeyParam(value: $0.baseAssetId)],
                [NMapKeyParam(value: $0.targetAssetId)]
            ]
        }
        return .multipleNMap(params: params)
    }
    
    var storagePath: any SSFModels.StorageCodingPathProtocol {
        return StorageCodingPath.poolReserves
    }
}
