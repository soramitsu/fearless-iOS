import Foundation
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

extension AsyncStorageRequestFactory {
    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [any Encodable],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        try await queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [[any NMapKeyParamProtocol]],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        try await queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: [Data],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        try await queryItems(
            engine: engine,
            keys: keys,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItemsByPrefix<T>(
        engine: JSONRPCEngine,
        key: Data,
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        try await queryItemsByPrefix(
            engine: engine,
            key: key,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: Data,
        childKeyParam: Data,
        factory: RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable
    ) async throws -> ChildStorageResponse<T> where T: Decodable {
        try await queryChildItem(
            engine: engine,
            storageKeyParam: storageKeyParam,
            childKeyParam: childKeyParam,
            factory: factory,
            mapper: mapper,
            at: nil
        )
    }
}
