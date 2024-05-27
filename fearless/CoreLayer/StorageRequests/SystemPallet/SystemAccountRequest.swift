import Foundation
import SSFModels

struct SystemAccountRequest: StorageRequest {
    let accountId: AccountIdVariant
    let chainAsset: ChainAsset

    var parametersType: StorageRequestParametersType {
        if let currencyId = chainAsset.currencyId {
            var accountIdParameter: NMapKeyParamProtocol
            switch accountId {
            case let .accountId(accountId):
                accountIdParameter = NMapKeyParam(value: accountId)
            case let .address(address):
                accountIdParameter = NMapKeyParam(value: address)
            }

            return .nMap(params: [[accountIdParameter], [NMapKeyParam(value: currencyId)]])
        } else {
            switch accountId {
            case let .accountId(accountId):
                return .encodable(param: accountId)
            case let .address(address):
                return .encodable(param: address)
            }
        }
    }

    var storagePath: StorageCodingPath {
        chainAsset.storagePath
    }
}
