import Foundation
import SSFModels

struct NominationPoolsPoolMembersRequest: StorageRequest {
    let accountId: AccountId

    var parametersType: StorageRequestParametersType {
        .encodable(param: accountId)
    }

    var storagePath: StorageCodingPath {
        .stakingPoolMembers
    }
}
