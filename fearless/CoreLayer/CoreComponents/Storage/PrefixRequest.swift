import Foundation
import SSFModels

protocol PrefixRequest {
    var storagePath: StorageCodingPath { get }
    var keyType: RuntimePrimitive { get }
    var parametersType: PrefixStorageRequestParametersType { get }
}

enum PrefixStorageRequestParametersType {
    case empty

    var workerType: StorageRequestWorkerType {
        switch self {
        case .empty:
            return .prefix
        }
    }
}
