import Foundation
import SSFModels

struct SystemAccountRequest: StorageRequest {
    let accountId: AccountId
    let chainAsset: ChainAsset

    var parametersType: StorageRequestParametersType {
        if let currencyId = chainAsset.currencyId {
            return .nMap(params: [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: currencyId)]])
        } else {
            return .encodable(param: accountId)
        }
    }

    var storagePath: StorageCodingPath {
        chainAsset.storagePath
    }
}
