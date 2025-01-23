import Foundation
import SSFModels

protocol PrefixRequest {
    var storagePath: StorageCodingPath { get }
    var keyType: MapKeyType { get }
    var parametersType: PrefixStorageRequestParametersType { get }
}

enum PrefixStorageRequestParametersType {
    case simple
    case encodable(params: [any Encodable])

    var workerType: StorageRequestWorkerType {
        switch self {
        case .simple:
            return .prefix
        case let .encodable(params):
            return .prefixEncodable(params: params)
        }
    }
}
