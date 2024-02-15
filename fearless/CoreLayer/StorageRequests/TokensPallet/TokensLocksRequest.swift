import Foundation
import SSFModels

struct TokensLocksRequest<T: Encodable>: StorageRequest {
    typealias K = T

    let accountId: T
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
