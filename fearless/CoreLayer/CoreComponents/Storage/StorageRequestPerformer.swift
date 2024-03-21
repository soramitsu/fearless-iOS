import Foundation
import SSFUtils
import SSFRuntimeCodingService
import RobinHood
import SSFModels

protocol StorageRequestPerformer {
    func performSingle<T: Decodable>(
        _ request: StorageRequest
    ) async throws -> T?

    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        withCacheOptions: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<T?, Error>

    func performMultiple<T: Decodable>(
        _ request: MultipleRequest
    ) async throws -> [T?]

    func performMultiple<T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<[T?], Error>

    func performPrefix<T: Decodable, K: Decodable & ScaleCodable>(
        _ request: PrefixRequest
    ) async throws -> [K: T]?
}

final class StorageRequestPerformerDefault: StorageRequestPerformer {
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private lazy var storageRequestFactory: AsyncStorageRequestFactory = {
        AsyncStorageRequestDefault()
    }()

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) {
        self.runtimeService = runtimeService
        self.connection = connection
    }

    // MARK: - StorageRequestPerformer

    func performSingle<T: Decodable>(_ request: StorageRequest) async throws -> T? {
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
        return value
    }

    func performSingle<T: Decodable>(
        _ request: StorageRequest,
        withCacheOptions: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<T?, Error> {
        AsyncThrowingStream<T?, Error> { continuation in
            Task {
                if withCacheOptions.contains(.onPerform) {
                    let value: T? = try await performSingle(request)
                    continuation.yield(value)
                    continuation.finish()
                    return
                }
            }
        }
    }

    func performMultiple<T: Decodable>(
        _ request: MultipleRequest
    ) async throws -> [T?] {
        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: request.parametersType.workerType
        )

        let valueExtractor = MultipleSingleStorageResponseValueExtractor()
        let response: [StorageResponse<T>] = try await worker.perform(
            params: request.parametersType.workerType,
            storagePath: request.storagePath
        )
        let values = try valueExtractor.extractValue(storageResponse: response)
        return values
    }

    func performMultiple<T: Decodable>(
        _ request: MultipleRequest,
        withCacheOptions: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<[T?], Error> {
        AsyncThrowingStream<[T?], Error> { continuation in
            Task {
                if withCacheOptions.contains(.onPerform) {
                    let value: [T?] = try await performMultiple(request)
                    continuation.yield(value)
                    continuation.finish()
                    return
                }
            }
        }
    }

    func performPrefix<T, K>(
        _ request: PrefixRequest
    ) async throws -> [K: T]? where T: Decodable, K: Decodable & ScaleCodable, K: Hashable {
        let worker = StorageRequestWorkerBuilderDefault<T>().buildWorker(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            type: .prefix
        )

        let valueExtractor = PrefixStorageResponseValueExtractor(runtimeService: runtimeService)
        let response: [StorageResponse<T>] = try await worker.perform(
            params: .prefix,
            storagePath: request.storagePath
        )
        let values: [K: T]? = try await valueExtractor.extractValue(request: request, storageResponse: response)
        return values
    }

    // MARK: - Private methods

    private func decode<T: Decodable>(
        payload: Data,
        codingFactory: RuntimeCoderFactoryProtocol,
        path: StorageCodingPath
    ) throws -> [T?] {
        let data = try JSONDecoder().decode([Data].self, from: payload)
        let decoder = StorageFallbackDecodingListWorker<T>(
            codingFactory: codingFactory,
            path: path,
            dataList: data
        )
        return try decoder.performDecoding()
    }
}
