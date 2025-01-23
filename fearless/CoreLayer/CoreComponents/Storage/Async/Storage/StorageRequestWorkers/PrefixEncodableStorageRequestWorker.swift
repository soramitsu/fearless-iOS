import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

final class PrefixEncodableStorageRequestWorker<P: Decodable>: StorageRequestWorker {
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
        params: StorageRequestWorkerType,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>] {
        guard case let .prefixEncodable(params) = params else {
            throw StorageRequestWorkerError.invalidParameters(
                moduleName: storagePath.moduleName,
                itemName: storagePath.itemName
            )
        }

        let coderFactoryOperation = try await runtimeService.fetchCoderFactory()

        let response: [StorageResponse<T>] = try await storageRequestFactory.queryItemsByPrefix(
            engine: connection,
            keyParams: params,
            factory: coderFactoryOperation,
            storagePath: storagePath,
            at: nil
        )
        return response
    }
}
