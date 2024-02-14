import Foundation
import SSFUtils
import RobinHood

protocol NetworkInfoFetching {
    func fetchCurrentBlock(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) async throws -> UInt32?
}

final class NetworkInfoFetchingImpl {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
    }

    private func createCurrentBlockOperation(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<UInt32?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> = storageRequestFactory.queryItems(
            engine: connection,
            keys: { [try StorageKeyFactory().key(from: .currentBlock)] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .currentBlock
        )

        let mapOperation = ClosureOperation<UInt32?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension NetworkInfoFetchingImpl: NetworkInfoFetching {
    func fetchCurrentBlock(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) async throws -> UInt32? {
        try await withCheckedThrowingContinuation { continuation in
            let currentBlockOperation = createCurrentBlockOperation(
                runtimeService: runtimeService,
                connection: connection
            )

            currentBlockOperation.targetOperation.completionBlock = {
                do {
                    let currentBlock = try currentBlockOperation.targetOperation.extractNoCancellableResultData()
                    return continuation.resume(with: .success(currentBlock))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }

            operationManager.enqueue(
                operations: currentBlockOperation.allOperations,
                in: .transient
            )
        }
    }
}
