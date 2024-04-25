import Foundation
import SSFModels

struct SystemAccountRequest: StorageRequest {
    let accountId: AccountIdVariant
    let chainAsset: ChainAsset

    var parametersType: StorageRequestParametersType {
        switch accountId {
        case let .accountId(accountId):
            return .encodable(param: accountId)
        case let .address(address):
            return .encodable(param: address)
        }
    }

    var storagePath: StorageCodingPath {
        chainAsset.storagePath
    }
}
