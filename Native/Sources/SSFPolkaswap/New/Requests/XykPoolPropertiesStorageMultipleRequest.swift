import Foundation
import SSFStorageQueryKit
import SSFModels

struct XykPoolPropertiesStorageMultipleRequest: MultipleRequest {
    var keyType: SSFStorageQueryKit.MapKeyType {
        .assetIds
    }
    
    let pairs: [AssetIdPair]
    
    var parametersType: SSFStorageQueryKit.MultipleStorageRequestParametersType {
        let params = pairs.compactMap {
            [[NMapKeyParam(value: $0.baseAssetId)], [NMapKeyParam(value: $0.targetAssetId)]]
        }
        return .multipleNMap(params: params)
    }
    
    var storagePath: any SSFModels.StorageCodingPathProtocol {
        SSFPolkaswap.StorageCodingPath.poolProperties
    }
    
    
}
