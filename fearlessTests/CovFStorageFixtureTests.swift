import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
@testable import fearless

/// Answers storage reads from JSON values, recording what was asked.
final class CovFStorageRequests: StorageRequestFactoryProtocol {
    struct CovFEntry {
        let key: Data
        let json: Data?
    }

    var entries: [String: [CovFEntry]] = [:]
    private(set) var stringParameters: [String: [String]] = [:]
    private(set) var requestedPaths: [fearless.StorageCodingPath] = []

    func put(_ path: fearless.StorageCodingPath, key: Data = Data(), value: Any?) throws {
        let json = try value.map { try JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed) }
        entries[path.itemName, default: []].append(CovFEntry(key: key, json: json))
    }

    private func query<T: Decodable>(
        path: fearless.StorageCodingPath,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        prepare: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try factory()
            try prepare()
            self.requestedPaths.append(path)
            return try self.entries[path.itemName, default: []].map { entry in
                let value = try entry.json.map { try JSONDecoder().decode(T.self, from: $0) }
                return StorageResponse(key: entry.key, data: entry.json, value: value)
            }
        })
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        query(path: storagePath, factory: factory) {
            let params = try keyParams()
            if let mapped = params as? [fearless.StringScaleMapper<UInt32>] {
                self.stringParameters[storagePath.itemName] = mapped.map { String($0.value) }
            }
        }
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        query(path: storagePath, factory: factory) { _ = try keys() }
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        query(path: storagePath, factory: factory) { _ = try keyParams() }
    }

    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1],
        keyParams2 _: @escaping () throws -> [K2], factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { .createWithError(unsupported()) }

    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data,
        childKeyParam _: @escaping () throws -> Data, factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable, at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> { .createWithError(unsupported()) }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        query(path: storagePath, factory: factory) { _ = try keys() }
    }

    private func unsupported() -> NSError { NSError(domain: "unexpected storage request", code: 1) }
}
