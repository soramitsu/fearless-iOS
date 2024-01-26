import Foundation
import SSFUtils
import RobinHood

protocol StorageRequestPerformer {
    func performRequest<T: Decodable>(_ request: any StorageRequest) async throws -> T?
}

final class StorageRequestPerformerImpl {
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let operationManager: OperationManagerProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationManager = operationManager
        self.storageRequestFactory = storageRequestFactory
    }
}

extension StorageRequestPerformerImpl: StorageRequestPerformer {
    func performRequest<T: Decodable>(_ request: any StorageRequest) async throws -> T? {
        let operationBuilder = BaseStorageRequestOperationBuilderFactory<T>().buildStorageRequestOperationBuilder(
            runtimeService: runtimeService,
            connection: connection,
            storageRequestFactory: storageRequestFactory,
            request: request
        )
        let networkWorker = BaseStorageNetworkWorkerFactory().buildNetworkWorker(operationManager: operationManager)
        let responseDecoder = try BaseStorageResponseDecoderFactory().buildResponseDecoder(for: request)

        let operation: CompoundOperationWrapper<[StorageResponse<T>]> = operationBuilder.createStorageRequestOperation(request: request)
        let response: [StorageResponse<T>] = try await networkWorker.fetch(using: operation)
        let decoded = try responseDecoder.decode(storageResponse: response)

        return decoded
    }
}
