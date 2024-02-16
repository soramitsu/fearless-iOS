import Foundation

struct BalancesLocksRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId

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
