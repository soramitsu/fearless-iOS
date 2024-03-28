import Foundation
import SSFModels

struct AssetsAccountRequest: StorageRequest {
    let accountId: AccountIdVariant
    let currencyId: CurrencyId

    var parametersType: StorageRequestParametersType {
        switch accountId {
        case let .accountId(accountId):
            return .nMap(params: [
                [NMapKeyParam(value: currencyId)],
                [NMapKeyParam(value: accountId)]
            ])
        case let .address(address):
            return .nMap(params: [
                [NMapKeyParam(value: currencyId)],
                [NMapKeyParam(value: address)]
            ])
        }
    }

    var storagePath: StorageCodingPath {
        .assetsAccount
    }
}
