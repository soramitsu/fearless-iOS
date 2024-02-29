import Foundation
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

protocol AsyncStorageRequestFactory {
    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [any Encodable],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: [Data],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: Data,
        childKeyParam: Data,
        factory: RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable,
        at blockHash: Data?
    ) async throws -> ChildStorageResponse<T> where T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [[any NMapKeyParamProtocol]],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable

    func queryItemsByPrefix<T>(
        engine: JSONRPCEngine,
        keys: [Data],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable
}
