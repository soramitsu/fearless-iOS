import Foundation
import RobinHood
import SSFChainRegistry
import SSFModels
import SSFRuntimeCodingService
import SSFSingleValueCache
import SSFUtils

protocol StorageRequestPerformer {
    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        chain: ChainModel
    ) async throws -> T?

    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<T>, Error>

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        chain: ChainModel
    ) async throws -> [K: T]?

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error>

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error>

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        chain: ChainModel
    ) async throws -> [K: T]?

    func perform(
        _ requests: [any MixStorageRequest],
        chain: ChainModel
    ) async throws -> [MixStorageResponse]
}

actor StorageRequestPerformerDefault: StorageRequestPerformer {
    private let chainRegistry: ChainRegistryProtocol

    private lazy var storageRequestFactory: AsyncStorageRequestFactory =
        AsyncStorageRequestDefault()

    private lazy var cacheStorage: AsyncSingleValueRepository =
        SingleValueCacheRepositoryFactoryDefault().createAsyncSingleValueCacheRepository()

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    // MARK: - StorageRequestPerformer

    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        chain: ChainModel
    ) async throws -> T? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ConnectionPoolError.noConnection
        }

        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: request.parametersType.workerType
        )

        let valueExtractor = SingleStorageResponseValueExtractor()
        let response: [StorageResponse<T>] = try await worker.perform(
            params: request.parametersType.workerType,
            storagePath: request.storagePath
        )
        let value = try valueExtractor.extractValue(storageResponse: response)
        try? save(
            response: response,
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        return value
    }

    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<T>, Error> {
        AsyncThrowingStream<CachedStorageResponse<T>, Error> { continuation in
            Task {
                if withCacheOptions == .onAll || withCacheOptions.isEmpty {
                    try? await getCacheSingleValue(for: request, with: continuation, chain: chain)
                    let value: T? = try await performSingle(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onCache) {
                    try await getCacheSingleValue(for: request, with: continuation, chain: chain)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onPerform) {
                    let value: T? = try await performSingle(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
            }
        }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        chain: ChainModel
    ) async throws -> [K: T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ConnectionPoolError.noConnection
        }

        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: request.parametersType.workerType
        )

        let valueExtractor =
            MultipleSingleStorageResponseValueExtractor(runtimeService: runtimeService)
        let response: [StorageResponse<T>] = try await worker.perform(
            params: request.parametersType.workerType,
            storagePath: request.storagePath
        )
        let values: [K: T]? = try await valueExtractor.extractValue(
            request: request,
            storageResponse: response
        )
        try? save(
            response: response,
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )

        return values
    }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error> { continuation in
            Task {
                if withCacheOptions == .onAll || withCacheOptions.isEmpty {
                    try? await getCacheMultipleValue(for: request, with: continuation, chain: chain)
                    let value: [K: T]? = try await performMultiple(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onCache) {
                    try await getCacheMultipleValue(for: request, with: continuation, chain: chain)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onPerform) {
                    let value: [K: T]? = try await performMultiple(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
            }
        }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        chain: ChainModel
    ) async throws -> [K: T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }

        guard let connection =  chainRegistry.getConnection(for: chain.chainId) else {
            throw ConnectionPoolError.noConnection
        }

        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: request.parametersType.workerType
        )

        let valueExtractor = PrefixStorageResponseValueExtractor(runtimeService: runtimeService)
        let response: [StorageResponse<T>] = try await worker.perform(
            params: request.parametersType.workerType,
            storagePath: request.storagePath
        )
        let values: [K: T]? = try await valueExtractor.extractValue(
            request: request,
            storageResponse: response
        )
        try? save(
            response: response,
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )

        return values
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error> {
        return AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error> { continuation in
            Task {
                if withCacheOptions == .onAll || withCacheOptions.isEmpty {
                    try? await getCachePagedValue(for: request, with: continuation, chain: chain)
                    let value: [K: T]? = try await performPrefix(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onCache) {
                    try await getCachePagedValue(for: request, with: continuation, chain: chain)
                    continuation.finish()
                    return
                }
                if withCacheOptions.contains(.onPerform) {
                    let value: [K: T]? = try await performPrefix(request, chain: chain)
                    let response = CachedStorageResponse(value: value, type: .remote)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
            }
        }
    }

    func perform(
        _ requests: [any MixStorageRequest],
        chain: ChainModel
    ) async throws -> [MixStorageResponse] {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ConnectionPoolError.noConnection
        }
        
        let codingFactory = try await runtimeService.fetchCoderFactory()
        let keysBuilder = MixStorageRequestsKeysBuilder(codingFactory: codingFactory)
        let requesrWorker = MixStorageRequestsWorkerDefault(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory
        )

        let keys = try keysBuilder.buildKeys(for: requests)
        let updates = try await requesrWorker.perform(keys: keys)

        let decodingWorker = MixStorageDecodingListWorker(
            requests: requests,
            updates: updates,
            codingFactory: codingFactory
        )
        let responses = try decodingWorker.performDecoding()

        return responses
    }

    // MARK: - Private methods

    private func getCacheSingleValue<T: Decodable>(
        for request: StorageRequest,
        with continuation: AsyncThrowingStream<CachedStorageResponse<T>, Error>.Continuation,
        chain: ChainModel
    ) async throws {
        let cache: [Data: T]? = try? await getCache(
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        guard let decoded = cache?.first?.value else {
            return
        }
        let response = CachedStorageResponse(value: decoded, type: .cache)
        continuation.yield(response)
    }

    private func getCacheMultipleValue<K: Decodable & Hashable, T: Decodable>(
        for request: MultipleRequest,
        with continuation: AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error>.Continuation,
        chain: ChainModel
    ) async throws where T: Decodable, K: Decodable & ScaleCodable, K: Hashable {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

        let cache: [Data: T]? = try? await getCache(
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        guard let cache = cache else {
            return
        }

        let resultArray: [[K: T]] = try await cache.asyncCompactMap {
            let key: K = try await keyExtractor.extractKey(
                storageKey: $0.key,
                storagePath: request.storagePath,
                type: request.keyType
            )
            return [key: $0.value]
        }
        let result = Dictionary(resultArray.flatMap { $0 }, uniquingKeysWith: { _, last in last })
        let response = CachedStorageResponse(value: result, type: .cache)
        continuation.yield(response)
    }

    private func getCachePagedValue<K, T>(
        for request: PrefixRequest,
        with continuation: AsyncThrowingStream<CachedStorageResponse<[K: T]>, Error>.Continuation,
        chain: ChainModel
    ) async throws where T: Decodable, K: Decodable & ScaleCodable, K: Hashable {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

        let cache: [Data: T]? = try? await getCache(
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        guard let cache = cache else {
            return
        }

        let resultArray: [[K: T]] = try await cache.asyncCompactMap {
            let key: K = try await keyExtractor.extractKey(
                storageKey: $0.key,
                storagePath: request.storagePath,
                type: request.keyType
            )
            return [key: $0.value]
        }
        let result = Dictionary(resultArray.flatMap { $0 }, uniquingKeysWith: { _, last in last })
        let response = CachedStorageResponse(value: result, type: .cache)
        continuation.yield(response)
    }

    private func getCache<T: Decodable>(
        params: StorageRequestWorkerType,
        storagePath: StorageCodingPath,
        chain: ChainModel
    ) async throws -> [Data: T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: chain.chainId
        ) else {
            throw RuntimeProviderError.providerUnavailable
        }
        
        let codingFactory = try await runtimeService.fetchCoderFactory()
        let keysEncoder = StorageRequestKeyEncodingWorkerFactoryDefault().buildFactory(
            storageCodingPath: storagePath,
            workerType: params,
            codingFactory: codingFactory,
            storageKeyFactory: StorageKeyFactory()
        )
        let keys = try keysEncoder.performEncoding()
        let localKeys = try keys.compactMap { try createKey(from: $0, key: chain.chainId) }
        let cache = try await cacheStorage.fetch(by: localKeys, options: RepositoryFetchOptions())

        let caches = cache.compactMap {
            let item: [Data: T]? = try? decode(
                object: $0,
                codingFactory: codingFactory,
                path: storagePath
            )
            return item
        }

        return Dictionary(caches.flatMap { $0 }, uniquingKeysWith: { _, last in last })
    }

    private func decode<T: Decodable>(
        object: SingleValueProviderObject,
        codingFactory: RuntimeCoderFactoryProtocol,
        path: StorageCodingPath
    ) throws -> [Data: T]? {
        let decoder = StorageFallbackDecodingListWorker<T>(
            codingFactory: codingFactory,
            path: path,
            dataList: [object.payload]
        )
        guard let value = try decoder.performDecoding().compactMap({ $0 }).first else {
            return nil
        }

        let key = Data(hex: object.identifier)

        return [key: value]
    }

    private func save<T: Decodable>(
        response: [StorageResponse<T>],
        params _: StorageRequestWorkerType,
        storagePath _: StorageCodingPath,
        chain: ChainModel
    ) throws {
        Task {
            let objects: [SingleValueProviderObject] = try response.compactMap {
                guard let data = $0.data else {
                    return nil
                }

                let identifier = try createKey(from: $0.key, key: chain.chainId)

                return SingleValueProviderObject(identifier: identifier, payload: data)
            }

            await cacheStorage.save(models: objects)
        }
    }

    private func createKey(from remoteKey: Data, key: String) throws -> String {
        let concatData = Data(key.utf8) + remoteKey
        return concatData.toHex()
    }
}
