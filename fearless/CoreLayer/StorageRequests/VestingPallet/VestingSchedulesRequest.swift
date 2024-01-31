import Foundation

struct VestingSchedulesRequest: StorageRequest {
    typealias K = AccountId

    let accountId: AccountId

    init(accountId: AccountId) {
        self.accountId = accountId
    }

    var storagePath: StorageCodingPath {
        .vestingSchedule
    }

    var responseType: StorageResponseType {
        .single
    }

    var parametersType: StorageRequestParametersType<AccountId> {
        .encodable(params: { [accountId] })
    }
}
