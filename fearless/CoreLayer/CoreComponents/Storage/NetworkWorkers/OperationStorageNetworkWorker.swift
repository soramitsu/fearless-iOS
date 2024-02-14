import Foundation
import RobinHood

final class OperationStorageNetworkWorker: StorageNetworkWorker {
    private let operationManager: OperationManagerProtocol

    init(operationManager: OperationManagerProtocol) {
        self.operationManager = operationManager
    }

    func fetch<T: Decodable>(using operation: CompoundOperationWrapper<[StorageResponse<T>]>) async throws -> [StorageResponse<T>] {
        try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let response = try operation.targetOperation.extractNoCancellableResultData()
                    return continuation.resume(with: .success(response))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }

            operationManager.enqueue(
                operations: operation.allOperations,
                in: .transient
            )
        }
    }
}
