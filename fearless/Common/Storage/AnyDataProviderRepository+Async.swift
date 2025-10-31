import Foundation
import RobinHood

// Lightweight async wrappers for Repository operations.
// These preserve existing operation-based APIs while enabling
// incremental migration to async/await without changing call sites.

extension AnyDataProviderRepository {
    private static var asyncQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "io.fearless.repository.async"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 2
        return q
    }()

    /// Fetches all items asynchronously.
    func fetchAllAsync(
        options: RepositoryFetchOptions = RepositoryFetchOptions()
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let op = fetchAllOperation(with: options)
            op.completionBlock = {
                do {
                    let result = try op.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            AnyDataProviderRepository.asyncQueue.addOperation(op)
        }
    }

    /// Saves items asynchronously using the repository's saveOperation.
    /// - Parameters:
    ///   - insert: Items to insert or update.
    ///   - delete: Items to delete.
    func saveAsync(
        insert: @escaping @autoclosure () -> [T],
        delete: @escaping @autoclosure () -> [T]
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let op = saveOperation(insert, delete)
            op.completionBlock = {
                if case let .failure(error) = op.result {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
            AnyDataProviderRepository.asyncQueue.addOperation(op)
        }
    }
}

