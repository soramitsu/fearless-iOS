import Foundation
import SSFModels

struct AssetsAccountRequest: StorageRequest {
    let accountId: AccountId
    let currencyId: CurrencyId

    var parametersType: StorageRequestParametersType {
        .nMap(params: [
            [NMapKeyParam(value: currencyId)],
            [NMapKeyParam(value: accountId)]
        ])
    }

    var storagePath: StorageCodingPath {
        .assetsAccount
    }
}
