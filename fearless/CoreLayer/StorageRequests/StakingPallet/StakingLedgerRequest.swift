import Foundation
import SSFModels

struct StakingLedgerRequest: StorageRequest {
    let accountId: AccountId

    var parametersType: StorageRequestParametersType {
        .encodable(param: accountId)
    }

    var storagePath: StorageCodingPath {
        .stakingLedger
    }
}
