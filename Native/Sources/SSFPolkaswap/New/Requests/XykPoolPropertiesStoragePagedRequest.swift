import Foundation
import SSFStorageQueryKit
import SSFModels
import SSFUtils

public struct XykPoolPropertiesStoragePagedRequest: PrefixRequest {
    public var keyType: SSFStorageQueryKit.MapKeyType {
        .assetIds
    }
    
    let baseAssetIds: [PolkaswapDexInfoAssetId]
    
    public var parametersType: PrefixStorageRequestParametersType {
        return .encodable(params: baseAssetIds)
    }

    public var storagePath: any SSFModels.StorageCodingPathProtocol {
        SSFPolkaswap.StorageCodingPath.poolProperties
    }
}
