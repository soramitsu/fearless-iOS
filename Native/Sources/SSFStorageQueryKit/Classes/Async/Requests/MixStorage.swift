import Foundation
import SSFModels
import SSFUtils

// MARK: - Request

public protocol MixStorageRequest {
    associatedtype Response: Decodable
    var responseType: Response.Type { get }

    var parametersType: MixStorageRequestParametersType { get }
    var storagePath: any StorageCodingPathProtocol { get }
    
    var requestId: String { get }
}

public extension MixStorageRequest {
    var responseType: Response.Type {
        Response.self
    }
    
    var responseTypeRegistry: String {
        String(describing: Response.self)
    }
}

public enum MixStorageRequestParametersType {
    case nMap(params: [[any NMapKeyParamProtocol]])
    case encodable(param: any Encodable)
    case simple

    var workerType: StorageRequestWorkerType {
        switch self {
        case let .nMap(params):
            return .nMap(params: [params])
        case let .encodable(param):
            return .encodable(params: [param])
        case .simple:
            return .simple
        }
    }
}

// MARK: - Response

public struct MixStorageResponse {
    public let request: any MixStorageRequest
    public let json: JSON?
}
