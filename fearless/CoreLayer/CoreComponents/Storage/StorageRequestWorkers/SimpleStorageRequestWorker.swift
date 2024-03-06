import Foundation
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

final class SimpleStorageRequestWorker<P: Decodable>: StorageRequestWorker {
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let storageRequestFactory: AsyncStorageRequestFactory

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: AsyncStorageRequestFactory
    ) {
        self.runtimeService = runtimeService
        self.connection = connection
        self.storageRequestFactory = storageRequestFactory
    }

    func perform<T>(
        params: StorageRequestWorkerType,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] where T: Decodable {
        guard case StorageRequestWorkerType.simple = params else {
            throw StorageRequestWorkerError.invalidParameters
        }

        let key = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )
        let coderFactory = try await runtimeService.fetchCoderFactory()
        let response: [StorageResponse<T>] = try await storageRequestFactory.queryItems(
            engine: connection,
            keys: [key],
            factory: coderFactory,
            storagePath: storagePath
        )
        return response
    }
}
