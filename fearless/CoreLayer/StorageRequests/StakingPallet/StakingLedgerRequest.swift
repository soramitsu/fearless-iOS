import Foundation
import SSFModels

struct StakingLedgerRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId

    var parametersType: StorageRequestParametersType<K> {
        .encodable {
            [accountId]
        }
    }

    var storagePath: StorageCodingPath {
        .stakingLedger
    }

    var responseType: StorageResponseType {
        .single
    }
}
