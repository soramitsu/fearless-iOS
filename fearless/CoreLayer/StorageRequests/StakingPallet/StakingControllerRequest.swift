import Foundation

struct StakingControllerRequest: StorageRequest {
    let accountId: AccountId

    var parametersType: StorageRequestParametersType {
        .encodable(param: accountId)
    }

    var storagePath: StorageCodingPath {
        .controller
    }
}
