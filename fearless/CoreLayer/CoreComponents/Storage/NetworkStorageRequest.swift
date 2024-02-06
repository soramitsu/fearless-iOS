import Foundation

enum StorageResponseType {
    case single
}

enum StorageRequestParametersType<K: Encodable> {
    case nMap(params: () throws -> [[any NMapKeyParamProtocol]])
    case encodable(params: () throws -> [K])
    case keys(params: () throws -> [Data])
    case childKeyParam(storageKeyParam: () throws -> Data, childKeyParam: () throws -> Data)
}

protocol StorageRequest {
    /*
     TODO: think about more convenient solution
     K - type of input parameter for encodable request parameter type. For another parameter types just use mock e.g. Data type
     */
    associatedtype K: Encodable
    var parametersType: StorageRequestParametersType<K> { get }
    var storagePath: StorageCodingPath { get }
    var responseType: StorageResponseType { get }
}
