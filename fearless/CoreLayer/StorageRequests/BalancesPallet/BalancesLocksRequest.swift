import Foundation

struct BalancesLocksRequest<T: Encodable>: StorageRequest {
    typealias K = T

    let accountId: T

    var parametersType: StorageRequestParametersType<K> {
        .encodable(params: { [accountId] })
    }

    var storagePath: StorageCodingPath {
        .balanceLocks
    }

    var responseType: StorageResponseType {
        .single
    }
}
