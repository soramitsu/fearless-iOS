import Foundation
import SSFModels

struct StakingLedgerRequest<T: Encodable>: StorageRequest {
    typealias K = T

    let accountId: T

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
