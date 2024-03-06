import Foundation

struct StakingControllerRequest: StorageRequest {
    let accountId: AccountIdVariant

    var parametersType: StorageRequestParametersType {
        switch accountId {
        case let .accountId(accountId):
            return .encodable(param: [accountId])
        case let .address(address):
            return .encodable(param: [address])
        }
    }

    var storagePath: StorageCodingPath {
        .controller
    }
}
