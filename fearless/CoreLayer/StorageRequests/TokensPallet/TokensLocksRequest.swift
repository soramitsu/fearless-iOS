import Foundation
import SSFModels

struct TokensLocksRequest: StorageRequest {
    let accountId: AccountId
    let currencyId: CurrencyId

    var parametersType: StorageRequestParametersType {
        .nMap(params: [
            [NMapKeyParam(value: accountId)],
            [NMapKeyParam(value: currencyId)]
        ])
    }

    var storagePath: StorageCodingPath {
        .tokensLocks
    }
}
