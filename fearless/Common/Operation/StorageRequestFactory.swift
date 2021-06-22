import Foundation
import RobinHood
import FearlessUtils

struct StorageResponse<T: Decodable> {
    let key: Data
    let data: Data?
    let value: T?
}

struct ChildStorageResponse<T: Decodable> {
    let storageKey: Data
    let childKey: Data
    let data: Data?
    let value: T?
}

protocol StorageRequestFactoryProtocol {
    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: @escaping () throws -> Data,
        childKeyParam: @escaping () throws -> Data,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> where T: Decodable
}

final class StorageRequestFactory: StorageRequestFactoryProtocol {
    let remoteFactory: StorageKeyFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(remoteFactory: StorageKeyFactoryProtocol, operationManager: OperationManagerProtocol) {
        self.remoteFactory = remoteFactory
        self.operationManager = operationManager
    }

    private func createMergeOperation<T>(
        dependingOn queryOperation: BaseOperation<[[StorageUpdate]]>,
        decodingOperation: BaseOperation<[T?]>,
        keys: @escaping () throws -> [Data]
    ) -> ClosureOperation<[StorageResponse<T>]> {
        ClosureOperation<[StorageResponse<T>]> {
            let result = try queryOperation.extractNoCancellableResultData().flatMap { $0 }

            let resultChangesData = result.flatMap { StorageUpdateData(update: $0).changes }

            let keyedEncodedItems = resultChangesData.reduce(into: [Data: Data]()) { result, change in
                if let data = change.value {
                    result[change.key] = data
                }
            }

            let allKeys = resultChangesData.map(\.key)

            let items = try decodingOperation.extractNoCancellableResultData()

            let keyedItems = zip(allKeys, items).reduce(into: [Data: T]()) { result, item in
                result[item.0] = item.1
            }

            let originalIndexedKeys = try keys().enumerated().reduce(into: [Data: Int]()) { result, item in
                result[item.element] = item.offset
            }

            return allKeys.map { key in
                StorageResponse(key: key, data: keyedEncodedItems[key], value: keyedItems[key])
            }.sorted { response1, response2 in
                guard
                    let index1 = originalIndexedKeys[response1.key],
                    let index2 = originalIndexedKeys[response2.key] else {
                    return false
                }

                return index1 < index2
            }
        }
    }

    private func createQueryOperation(
        for keys: @escaping () throws -> [Data],
        at blockHash: Data?,
        engine: JSONRPCEngine
    ) -> BaseOperation<[[StorageUpdate]]> {
        OperationCombiningService<[StorageUpdate]>(
            operationManager: operationManager) {
            let keys = try keys()

            let itemsPerPage = 1000
            let pageCount = (keys.count % itemsPerPage == 0) ?
                keys.count / itemsPerPage : (keys.count / itemsPerPage + 1)

            let wrappers: [CompoundOperationWrapper<[StorageUpdate]>] = (0 ..< pageCount).map { pageIndex in
                let pageStart = pageIndex * itemsPerPage
                let pageEnd = pageStart + itemsPerPage
                let subkeys = (pageEnd < keys.count) ?
                    Array(keys[pageStart ..< pageEnd]) :
                    Array(keys.suffix(from: pageStart))

                let params = StorageQuery(keys: subkeys, blockHash: blockHash)

                let queryOperation = JSONRPCQueryOperation(
                    engine: engine,
                    method: RPCMethod.queryStorageAt,
                    parameters: params
                )

                return CompoundOperationWrapper(targetOperation: queryOperation)
            }

            if !wrappers.isEmpty {
                for index in 1 ..< wrappers.count {
                    wrappers[index].allOperations
                        .forEach { $0.addDependency(wrappers[0].targetOperation) }
                }
            }

            return wrappers
        }.longrunOperation()
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        let queryOperation = createQueryOperation(for: keys, at: blockHash, engine: engine)

        let decodingOperation = StorageFallbackDecodingListOperation<T>(path: storagePath)
        decodingOperation.configurationBlock = {
            do {
                let result = try queryOperation.extractNoCancellableResultData().flatMap { $0 }

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result
                    .flatMap { StorageUpdateData(update: $0).changes }
                    .map(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mergeOperation = createMergeOperation(
            dependingOn: queryOperation,
            decodingOperation: decodingOperation,
            keys: keys
        )

        mergeOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
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
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath, at: blockHash)

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
        storagePath: StorageCodingPath,
        at blockHash: Data?
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
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath, at: blockHash)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: @escaping () throws -> Data,
        childKeyParam: @escaping () throws -> Data,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable,
        at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> where T: Decodable {
        let queryOperation = JSONRPCListOperation<String?>(engine: engine, method: RPCMethod.getChildStorageAt)
        queryOperation.configurationBlock = {
            do {
                let childKey = try childKeyParam().toHex(includePrefix: true)
                let storageKey = try storageKeyParam().toHex(includePrefix: true)

                queryOperation.parameters = [childKey, storageKey]
            } catch {
                queryOperation.result = .failure(error)
            }
        }

        let decodingOperation = ClosureOperation<ChildStorageResponse<T>> {
            let maybeResult = try queryOperation.extractNoCancellableResultData()

            let childKey = try childKeyParam()
            let storageKey = try storageKeyParam()

            if let hexData = maybeResult {
                let data = try Data(hexString: hexData)

                let decoder = try factory().createDecoder(from: data)

                let json = try mapper.accept(decoder: decoder)

                let value = try json.map(to: T.self)

                return ChildStorageResponse(storageKey: storageKey, childKey: childKey, data: data, value: value)
            } else {
                return ChildStorageResponse(storageKey: storageKey, childKey: childKey, data: nil, value: nil)
            }
        }

        decodingOperation.addDependency(queryOperation)

        return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: [queryOperation])
    }
}

extension StorageRequestFactoryProtocol {
    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        queryItems(
            engine: engine,
            keyParams1: keyParams1,
            keyParams2: keyParams2,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        queryItems(
            engine: engine,
            keys: keys,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: @escaping () throws -> Data,
        childKeyParam: @escaping () throws -> Data,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> where T: Decodable {
        queryChildItem(
            engine: engine,
            storageKeyParam: storageKeyParam,
            childKeyParam: childKeyParam,
            factory: factory,
            mapper: mapper,
            at: nil
        )
    }
}
