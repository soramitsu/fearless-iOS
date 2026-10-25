import Foundation
import SSFStorageQueryKit
import SSFUtils
import SSFModels

struct UserPoolsStorageRequest: PrefixRequest {
    let accountId: Data

    var keyType: SSFStorageQueryKit.MapKeyType {
        .accountPoolsKey
    }
    
    var parametersType: PrefixStorageRequestParametersType {
        .encodable(params: [accountId])
    }
    
    var storagePath: any SSFModels.StorageCodingPathProtocol {
        StorageCodingPath.userPools
    }
}
