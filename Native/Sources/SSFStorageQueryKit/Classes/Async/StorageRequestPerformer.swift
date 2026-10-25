import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFSingleValueCache
import SSFUtils
import SSFChainRegistry

public protocol StorageRequestPerformer {
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
    ) async throws -> [K:T]?

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>
    
    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        chain: ChainModel
    ) async throws -> [K: T]?
    
    func perform(
        _ requests: [any MixStorageRequest],
        chain: ChainModel
    ) async throws -> [MixStorageResponse]
}

public actor StorageRequestPerformerDefault: StorageRequestPerformer {
    private let chainRegistry: ChainRegistryProtocol
    
    private lazy var storageRequestFactory: AsyncStorageRequestFactory =
        AsyncStorageRequestDefault()

    private lazy var cacheStorage: AsyncAnyRepository<SingleValueProviderObject> = {
        AsyncAnyRepository(SingleValueCacheRepositoryFactoryDefault().createAsyncSingleValueCacheRepository())
    }()

    public init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        cacheStorage: AsyncAnyRepository<SingleValueProviderObject>
    ) {
        self.chainRegistry = chainRegistry
        self.cacheStorage = cacheStorage
    }

    // MARK: - StorageRequestPerformer

    public func performSingle<T: Decodable>(
        _ request: StorageRequest,
        chain: ChainModel
    ) async throws -> T? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        
        let connection = try chainRegistry.getSubstrateConnection(for: chain)
        
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
        save(response: response, chainId: chain.chainId)
        return value
    }

    public func performSingle<T: Decodable>(
        _ request: StorageRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<T>, Error> {
        CachedStorageStream.make(
            options: withCacheOptions,
            readCache: { continuation in
                try await self.getCacheSingleValue(for: request, with: continuation, chain: chain)
            },
            fetchRemote: {
                try await self.performSingle(request, chain: chain)
            }
        )
    }

    public func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        chain: ChainModel
    ) async throws -> [K:T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        
        let connection = try chainRegistry.getSubstrateConnection(for: chain)
        
        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: request.parametersType.workerType
        )

        let valueExtractor = MultipleSingleStorageResponseValueExtractor(runtimeService: runtimeService)
        let response: [StorageResponse<T>] = try await worker.perform(
            params: request.parametersType.workerType,
            storagePath: request.storagePath
        )
        let values: [K:T]? = try await valueExtractor.extractValue(request: request, storageResponse: response)
        save(response: response, chainId: chain.chainId)

        return values
    }

    public func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>  {
        CachedStorageStream.make(
            options: withCacheOptions,
            readCache: { continuation in
                try await self.getCacheMultipleValue(for: request, with: continuation, chain: chain)
            },
            fetchRemote: {
                try await self.performMultiple(request, chain: chain)
            }
        )
    }

    public func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        chain: ChainModel
    ) async throws -> [K: T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        
        let connection = try chainRegistry.getSubstrateConnection(for: chain)
        
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
        let values: [K: T]? = try await valueExtractor.extractValue(request: request, storageResponse: response)
        save(response: response, chainId: chain.chainId)

        return values
    }
    
    public func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _ request: PrefixRequest,
        withCacheOptions: CachedStorageRequestTrigger,
        chain: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>  {
        CachedStorageStream.make(
            options: withCacheOptions,
            readCache: { continuation in
                try await self.getCachePagedValue(for: request, with: continuation, chain: chain)
            },
            fetchRemote: {
                try await self.performPrefix(request, chain: chain)
            }
        )
    }

    public func perform(
        _ requests: [any MixStorageRequest],
        chain: ChainModel
    ) async throws -> [MixStorageResponse] {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        
        let connection = try chainRegistry.getSubstrateConnection(for: chain)
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
        let cache: [Data:T]? = try await getCache(
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
        with continuation: AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>.Continuation,
        chain: ChainModel
    ) async throws where T: Decodable, K: Decodable & ScaleCodable, K: Hashable {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

        let cache: [Data:T]? = try await getCache(
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        guard let cache = cache else {
            return
        }
        
        let resultArray: [[K:T]] = try await cache.asyncCompactMap {
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
        with continuation: AsyncThrowingStream<CachedStorageResponse<[K:T]>, Error>.Continuation,
        chain: ChainModel
    ) async throws where T: Decodable, K: Decodable & ScaleCodable, K: Hashable {
        let runtimeService = try await chainRegistry.getRuntimeProvider(
            chainId: chain.chainId,
            usedRuntimePaths: [:],
            runtimeItem: nil
        )
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)
        
        let cache: [Data:T]? = try await getCache(
            params: request.parametersType.workerType,
            storagePath: request.storagePath,
            chain: chain
        )
        guard let cache = cache else {
            return
        }
        
        let resultArray: [[K:T]] = try await cache.asyncCompactMap {
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
        storagePath: any StorageCodingPathProtocol,
        chain: ChainModel
    ) async throws -> [Data:T]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
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
        let identifiers = keys.map { StorageCacheKey.encode(remoteKey: $0, chainId: chain.chainId) }
        let cache = try await cacheStorage.fetch(by: identifiers, options: RepositoryFetchOptions())

         let caches = cache.compactMap {
            let item: [Data:T]? = try? decode(
                object: $0,
                codingFactory: codingFactory,
                path: storagePath,
                chainId: chain.chainId
            )
            return item
        }
            
        return Dictionary(caches.flatMap { $0 }, uniquingKeysWith: { _, last in last })
    }

    private func decode<T: Decodable>(
        object: SingleValueProviderObject,
        codingFactory: RuntimeCoderFactoryProtocol,
        path: any StorageCodingPathProtocol,
        chainId: ChainModel.Id
    ) throws -> [Data:T]? {
        // Never infer an owner for legacy unscoped rows, or accept a foreign chain's row.
        guard let key = StorageCacheKey.remoteKey(from: object.identifier, chainId: chainId) else {
            return nil
        }
        let decoder = StorageFallbackDecodingListWorker<T>(
            codingFactory: codingFactory,
            path: path,
            dataList: [object.payload]
        )
        guard let value = try decoder.performDecoding().compactMap({ $0 }).first else {
            return nil
        }
        
        return [key: value]
    }

    private func save<T: Decodable>(
        response: [StorageResponse<T>],
        chainId: ChainModel.Id
    ) {
        Task {
            let objects: [SingleValueProviderObject] = response.compactMap {
                guard let data = $0.data else {
                    return nil
                }
                
                let identifier = StorageCacheKey.encode(remoteKey: $0.key, chainId: chainId)
                return SingleValueProviderObject(identifier: identifier, payload: data)
            }
            
            await cacheStorage.save(models: objects)
        }
    }
}


extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            if let transformed = try await transform(element) {
                values.append(transformed)
            }
        }

        return values
    }

    func asyncReduce<T>(
        _ initialResult: T,
        _ nextPartialResult:
        (_ partialResult: T, Element) async throws -> T
    ) async rethrows -> T {
        var accumulator = initialResult
        for element in self {
            accumulator = try await nextPartialResult(accumulator, element)
        }
        return accumulator
    }

    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}
