import Foundation
import SSFModels

public protocol PrefixRequest {
    var storagePath: any StorageCodingPathProtocol { get }
    var keyType: MapKeyType { get }
    var parametersType: PrefixStorageRequestParametersType { get }
}

public enum PrefixStorageRequestParametersType {
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
