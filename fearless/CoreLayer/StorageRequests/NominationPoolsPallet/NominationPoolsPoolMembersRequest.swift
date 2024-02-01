import Foundation
import SSFModels

struct NominationPoolsPoolMembersRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId

    var parametersType: StorageRequestParametersType<K> {
        .encodable {
            [accountId]
        }
    }

    var storagePath: StorageCodingPath {
        .stakingPoolMembers
    }

    var responseType: StorageResponseType {
        .single
    }
}
