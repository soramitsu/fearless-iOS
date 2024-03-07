import Foundation
import SSFUtils
import SSFRuntimeCodingService
import SSFModels

final class PrefixStorageRequestWorker<P: Decodable>: StorageRequestWorker {
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

    func perform<T: Decodable>(
        params _: StorageRequestWorkerType,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] {
        let coderFactoryOperation = try await runtimeService.fetchCoderFactory()
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )
        let response: [StorageResponse<T>] = try await storageRequestFactory.queryItemsByPrefix(
            engine: connection,
            key: key,
            factory: coderFactoryOperation,
            storagePath: storagePath
        )
        return response
    }
}
