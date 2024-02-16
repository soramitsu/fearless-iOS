import Foundation

struct SystemNumberRequest: StorageRequest {
    var parametersType: StorageRequestParametersType<Data>

    typealias K = Data

    var storagePath: StorageCodingPath {
        .blockNumber
    }

    var responseType: StorageResponseType {
        .single
    }
}
