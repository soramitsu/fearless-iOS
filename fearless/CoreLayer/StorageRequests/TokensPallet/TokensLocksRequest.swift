import Foundation
import SSFModels

struct TokensLocksRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId
    let currencyId: CurrencyId

    var parametersType: StorageRequestParametersType<K> {
        .nMap {
            [
                [NMapKeyParam(value: accountId)],
                [NMapKeyParam(value: currencyId)]
            ]
        }
    }

    var storagePath: StorageCodingPath {
        .tokensLocks
    }

    var responseType: StorageResponseType {
        .single
    }
}
