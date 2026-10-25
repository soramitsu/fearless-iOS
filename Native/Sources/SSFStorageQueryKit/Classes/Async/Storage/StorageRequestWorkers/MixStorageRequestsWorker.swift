import Foundation
import SSFRuntimeCodingService
import SSFUtils

protocol MixStorageRequestWorker {
    func perform(keys: [Data]) async throws -> [[StorageUpdate]]
}

final class MixStorageRequestsWorkerDefault: MixStorageRequestWorker {
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
    
    func perform(keys: [Data]) async throws -> [[StorageUpdate]] {
        let updates = try await storageRequestFactory.queryWorkersResult(
            for: keys,
            at: nil,
            engine: connection
        )
        return updates
    }
}
