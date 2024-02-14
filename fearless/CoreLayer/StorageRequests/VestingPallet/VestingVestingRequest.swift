import Foundation

struct VestingVestingRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId

    init(accountId: AccountId) {
        self.accountId = accountId
    }

    var storagePath: StorageCodingPath {
        .vestingVesting
    }

    var responseType: StorageResponseType {
        .single
    }

    var parametersType: StorageRequestParametersType<AccountId> {
        .encodable(params: { [accountId] })
    }
}
