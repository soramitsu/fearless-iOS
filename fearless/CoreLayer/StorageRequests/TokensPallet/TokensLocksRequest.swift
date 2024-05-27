import Foundation
import SSFModels

struct TokensLocksRequest: StorageRequest {
    let accountId: AccountIdVariant
    let currencyId: CurrencyId

    var parametersType: StorageRequestParametersType {
        switch accountId {
        case let .accountId(accountId):
            return .nMap(params: [
                [NMapKeyParam(value: accountId)],
                [NMapKeyParam(value: currencyId)]
            ])
        case let .address(address):
            return .nMap(params: [
                [NMapKeyParam(value: address)],
                [NMapKeyParam(value: currencyId)]
            ])
        }
    }

    var storagePath: StorageCodingPath {
        .tokensLocks
    }
}
