import Foundation

struct BalancesLocksRequest: StorageRequest {
    let accountId: AccountId

    var parametersType: StorageRequestParametersType {
        .encodable(param: [accountId])
    }

    var storagePath: StorageCodingPath {
        .balanceLocks
    }
}
