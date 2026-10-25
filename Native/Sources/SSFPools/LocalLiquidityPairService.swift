import Foundation
import RobinHood

public protocol LocalLiquidityPairService {
    func get() async throws -> [LiquidityPair]
    func sync(remotePairs: [LiquidityPair]) async throws
}

public final class LocalLiquidityPairServiceDefault {
    struct Changes {
        let newOrUpdatedItems: [LiquidityPair]
        let removedItems: [LiquidityPair]
    }

    private let repository: AnyDataProviderRepository<LiquidityPair>
    private let operationManager: OperationManagerProtocol

    public init(
        repository: AnyDataProviderRepository<LiquidityPair>,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension LocalLiquidityPairServiceDefault: LocalLiquidityPairService {
    public func get() async throws -> [LiquidityPair] {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationManager.enqueue(operations: [fetchOperation], in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            fetchOperation.completionBlock = {
                do {
                    let localPairs = try fetchOperation.extractNoCancellableResultData()
                    continuation.resume(returning: localPairs)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func sync(remotePairs: [LiquidityPair]) async throws {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let processingOperation: BaseOperation<Changes> = ClosureOperation {
            let remotePairs = Set(remotePairs)
            let localPairs = try Set(fetchOperation.extractNoCancellableResultData())
            let newOrUpdatedItems = remotePairs.subtracting(localPairs)
            let removedItems = localPairs.subtracting(remotePairs)
            return Changes(
                newOrUpdatedItems: Array(newOrUpdatedItems),
                removedItems: Array(removedItems)
            )
        }

        let localSaveOperation = repository.saveOperation({
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.pairId)
        })

        processingOperation.addDependency(fetchOperation)
        localSaveOperation.addDependency(processingOperation)

        operationManager.enqueue(
            operations: [fetchOperation, processingOperation, localSaveOperation],
            in: .transient
        )

        return try await withCheckedThrowingContinuation { continuation in
            localSaveOperation.completionBlock = {
                do {
                    try localSaveOperation.extractNoCancellableResultData()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
