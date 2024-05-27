import Foundation
import SSFModels

protocol MultipleRequest {
    var parametersType: MultipleStorageRequestParametersType { get }
    var storagePath: StorageCodingPath { get }
}

enum MultipleStorageRequestParametersType {
    case multipleNMap(params: [[any NMapKeyParamProtocol]])
    case multipleEncodable(params: [any Encodable])

    var workerType: StorageRequestWorkerType {
        switch self {
        case let .multipleNMap(params):
            return .nMap(params: params)
        case let .multipleEncodable(params):
            return .encodable(params: params)
        }
    }
}
