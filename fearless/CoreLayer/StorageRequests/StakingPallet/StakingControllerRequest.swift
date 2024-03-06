import Foundation

struct StakingControllerRequest<T: Encodable>: StorageRequest {
    typealias K = T

    let accountId: T

    var parametersType: StorageRequestParametersType<K> {
        .encodable {
            [accountId]
        }
    }

    var storagePath: StorageCodingPath {
        .controller
    }

    var responseType: StorageResponseType {
        .single
    }
}
