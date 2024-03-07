import Foundation

struct SystemNumberRequest: StorageRequest {
    var parametersType: StorageRequestParametersType {
        .simple
    }

    var storagePath: StorageCodingPath {
        .blockNumber
    }
}
