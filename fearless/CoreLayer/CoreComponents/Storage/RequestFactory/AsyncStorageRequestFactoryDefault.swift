import Foundation
import SSFUtils
import SSFRuntimeCodingService
import SSFModels

final class AsyncStorageRequestDefault: AsyncStorageRequestFactory {
    private lazy var storageKeyFactory: StorageKeyFactoryProtocol = {
        StorageKeyFactory()
    }()

    // MARK: - AsyncStorageRequestFactory

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [any Encodable],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        let keysWorker = MapKeyEncodingWorker(
            codingFactory: factory,
            path: storagePath,
            storageKeyFactory: storageKeyFactory,
            keyParams: keyParams
        )
        let keys = try keysWorker.performEncoding()

        let queryItems: [StorageResponse<T>] = try await queryItems(
            engine: engine,
            keys: keys,
            factory: factory,
            storagePath: storagePath,
            at: blockHash
        )
        return queryItems
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: [Data],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        let queryResult = try await queryWorkersResult(
            for: keys,
            at: blockHash,
            engine: engine
        )
        let dataList = queryResult
            .flatMap { $0 }
            .flatMap { StorageUpdateData(update: $0).changes }
            .map { $0.value }

        let decodingWorker = StorageFallbackDecodingListWorker<T>(
            codingFactory: factory,
            path: storagePath,
            dataList: dataList
        )
        let decoded = try decodingWorker.performDecoding()

        let result = mergeResult(updates: queryResult, decoded: decoded, keys: keys)
        return result
    }

    func queryChildItem<T>(
        engine: JSONRPCEngine,
        storageKeyParam: Data,
        childKeyParam: Data,
        factory: RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable,
        at _: Data?
    ) async throws -> ChildStorageResponse<T> where T: Decodable {
        let childKey = childKeyParam.toHex(includePrefix: true)
        let storageKey = storageKeyParam.toHex(includePrefix: true)

        let queryListWorker = JSONRPCListWorker<String?>(
            engine: engine,
            method: RPCMethod.getChildStorageAt,
            parameters: [childKey, storageKey]
        )
        let queryResponse = try await queryListWorker.performCall()

        let decodingWorker = ChildStorageResponseDecodingWorker<T>(
            factory: factory,
            mapper: mapper,
            queryResponse: queryResponse,
            storageKey: storageKeyParam,
            childKey: childKeyParam
        )
        let result = try decodingWorker.performDecode()
        return result
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keyParams: [[any NMapKeyParamProtocol]],
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        let keysWorker = NMapKeyEncodingWorker(
            codingFactory: factory,
            path: storagePath,
            storageKeyFactory: storageKeyFactory,
            keyParams: keyParams
        )
        let keys = try keysWorker.performEncoding()

        let queryItems: [StorageResponse<T>] = try await queryItems(
            engine: engine,
            keys: keys,
            factory: factory,
            storagePath: storagePath,
            at: blockHash
        )
        return queryItems
    }

    func queryItemsByPrefix<T>(
        engine: JSONRPCEngine,
        key: Data,
        factory: RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        let queryKeys = try await createQueryByPrefixOperation(for: key, engine: engine)
        let fetchedKeys = try queryKeys
            .compactMap { try Data(hexStringSSF: $0) }

        let queryItems = try await queryWorkersResult(for: fetchedKeys, at: blockHash, engine: engine)
        let result = queryItems
            .flatMap { $0 }
            .flatMap { StorageUpdateData(update: $0).changes }
            .map(\.value)

        let decodingWorker = StorageFallbackDecodingListWorker<T>(
            codingFactory: factory,
            path: storagePath,
            dataList: result
        )
        let decoded = try decodingWorker.performDecoding()

        let mergeResult = mergeResult(
            updates: queryItems,
            decoded: decoded,
            keys: [key]
        )
        return mergeResult
    }

    // MARK: - Private methods

    private func queryWorkersResult(
        for keys: [Data],
        at blockHash: Data?,
        engine: JSONRPCEngine
    ) async throws -> [[StorageUpdate]] {
        let itemsPerPage = 1000

        let pageCount = (keys.count % itemsPerPage == 0)
            ? keys.count / itemsPerPage
            : (keys.count / itemsPerPage + 1)

        let workers = (0 ..< pageCount).map { pageIndex in
            let pageStart = pageIndex * itemsPerPage
            let pageEnd = pageStart + itemsPerPage
            let subkeys = (pageEnd < keys.count)
                ? Array(keys[pageStart ..< pageEnd])
                : Array(keys.suffix(from: pageStart))

            let params = StorageQuery(keys: subkeys, blockHash: blockHash)
            let worker = JSONRPCWorker<StorageQuery, [StorageUpdate]>(
                engine: engine,
                method: RPCMethod.queryStorageAt,
                parameters: params
            )
            return worker
        }

        let updates = try await runRPCWorkers(workers)
        return updates
    }

    private func mergeResult<T>(
        updates: [[StorageUpdate]],
        decoded: [T?],
        keys: [Data]
    ) -> [StorageResponse<T>] {
        let resultChangesData = updates
            .flatMap { $0 }
            .flatMap { StorageUpdateData(update: $0).changes }

        let keyedEncodedItems = resultChangesData.reduce(into: [Data: Data]()) { result, change in
            if let data = change.value {
                result[change.key] = data
            }
        }

        let allKeys = resultChangesData.map(\.key)

        let keyedItems = zip(allKeys, decoded).reduce(into: [Data: T]()) { result, item in
            result[item.0] = item.1
        }

        let originalIndexedKeys = keys.enumerated().reduce(into: [Data: Int]()) { result, item in
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

    private func createQueryByPrefixOperation(
        for key: Data,
        engine: JSONRPCEngine
    ) async throws -> [String] {
        let itemsPerPage = 1000

        var result: [String] = []
        var full = false
        var offset: String?

        while !full {
            let request = PagedKeysRequest(
                key: key.toHex(includePrefix: true),
                count: UInt32(itemsPerPage),
                offset: offset
            )
            let worker = JSONRPCWorker<PagedKeysRequest, [String]>(
                engine: engine,
                method: RPCMethod.getStorageKeysPaged,
                parameters: request
            )

            let page = try await worker.performCall()
            result += page
            offset = page.last
            full = page.count < itemsPerPage
        }

        return result
    }

    private func runRPCWorkers<P: Encodable, T: Decodable>(
        _ workers: [JSONRPCWorker<P, T>]
    ) async throws -> [T] {
        try await withThrowingTaskGroup(
            of: T.self,
            returning: [T].self,
            body: { group in
                workers.forEach { worker in
                    group.addTask {
                        try await worker.performCall()
                    }
                }
                var storageUpdate: [T] = []
                for try await storage in group {
                    storageUpdate.append(storage)
                }
                return storageUpdate
            }
        )
    }
}

public enum AsyncStorageRequestError: Error {
    case unexpectedDependentResult
}
