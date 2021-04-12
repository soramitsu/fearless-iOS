import Foundation
import RobinHood
import FearlessUtils

struct StorageResponse<T: Decodable> {
    let key: Data
    let data: Data?
    let value: T?
}

protocol StorageRequestFactoryProtocol {
    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable
}

final class StorageRequestFactory: StorageRequestFactoryProtocol {
    let remoteFactory: StorageKeyFactoryProtocol

    init(remoteFactory: StorageKeyFactoryProtocol) {
        self.remoteFactory = remoteFactory
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        let queryOperation = JSONRPCQueryOperation(
            engine: engine,
            method: RPCMethod.queryStorageAt
        )
        queryOperation.configurationBlock = {
            do {
                let keys = try keys().map { $0.toHex(includePrefix: true) }
                queryOperation.parameters = [keys]
            } catch {
                queryOperation.result = .failure(error)
            }
        }

        let decodingOperation = StorageDecodingListOperation<T>(path: storagePath)
        decodingOperation.configurationBlock = {
            do {
                let result = try queryOperation.extractNoCancellableResultData()

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result
                    .flatMap { StorageUpdateData(update: $0).changes }
                    .compactMap(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mapOperation = ClosureOperation<[StorageResponse<T>]> {
            let result = try queryOperation.extractNoCancellableResultData()

            let resultChangesData = result.flatMap { StorageUpdateData(update: $0).changes }

            let keyedEncodedItems = resultChangesData.reduce(into: [Data: Data]()) { result, change in
                if let data = change.value {
                    result[change.key] = data
                }
            }

            let allKeys = resultChangesData.map(\.key)

            let allNonzeroKeys = resultChangesData.compactMap { $0.value != nil ? $0.key : nil }

            let items = try decodingOperation.extractNoCancellableResultData()

            let keyedItems = zip(allNonzeroKeys, items).reduce(into: [Data: T]()) { result, item in
                result[item.0] = item.1
            }

            return allKeys.map { key in
                StorageResponse(key: key, data: keyedEncodedItems[key], value: keyedItems[key])
            }
        }

        mapOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        let keysOperation = MapKeyEncodingOperation<K>(
            path: storagePath,
            storageKeyFactory: remoteFactory
        )

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams = try keyParams()
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let keys: () throws -> [Data] = {
            try keysOperation.extractNoCancellableResultData()
        }

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        let keysOperation = DoubleMapKeyEncodingOperation<K1, K2>(path: storagePath, storageKeyFactory: remoteFactory)

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams1 = try keyParams1()
                keysOperation.keyParams2 = try keyParams2()
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let keys: () throws -> [Data] = {
            try keysOperation.extractNoCancellableResultData()
        }

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
