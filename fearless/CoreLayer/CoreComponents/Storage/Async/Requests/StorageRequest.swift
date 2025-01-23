import Foundation
import SSFModels

protocol StorageRequest {
    var parametersType: StorageRequestParametersType { get }
    var storagePath: StorageCodingPath { get }
}

enum StorageRequestParametersType {
    case nMap(params: [[any NMapKeyParamProtocol]])
    case encodable(param: any Encodable)
    case simple
    case prefix

    var workerType: StorageRequestWorkerType {
        switch self {
        case let .nMap(params):
            return .nMap(params: [params])
        case let .encodable(param):
            return .encodable(params: [param])
        case .simple:
            return .simple
        case .prefix:
            return .prefix
        }
    }
}
