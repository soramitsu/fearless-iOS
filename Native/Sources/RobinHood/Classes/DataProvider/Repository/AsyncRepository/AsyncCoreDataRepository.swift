import CoreData
import Foundation

public protocol AsyncCoreDataRepository {
    associatedtype Model: Identifiable

    func fetch(
        by modelIds: [String],
        options: RepositoryFetchOptions
    ) async throws -> [Model]

    func fetch(
        by modelId: String,
        options: RepositoryFetchOptions
    ) async throws -> Model?

    func fetchAll(
        with options: RepositoryFetchOptions
    ) async throws -> [Model]

    func save(
        models: [Model],
        deleteIds: [String]
    ) async
}

public extension AsyncCoreDataRepository {
    func fetch(by modelId: String) async throws -> Model? {
        try await fetch(by: modelId, options: RepositoryFetchOptions())
    }

    func fetchAll() async throws -> [Model] {
        try await fetchAll(with: RepositoryFetchOptions())
    }

    func save(models: [Model]) async {
        await save(models: models, deleteIds: [])
    }

    func remove(ids: [String]) async {
        await save(models: [], deleteIds: ids)
    }
}

public final class AsyncCoreDataRepositoryDefault<
    T: Identifiable,
    U: NSManagedObject
>: AsyncCoreDataRepository {
    public typealias Model = T

    private let coreDataRepository: CoreDataRepository<T, U>
    private lazy var operationQueue: OperationQueue = .init()

    public init(
        databaseService: CoreDataServiceProtocol,
        mapper: AnyCoreDataMapper<T, U>,
        filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) {
        coreDataRepository = CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    public func fetch(
        by modelIds: [String],
        options: RepositoryFetchOptions
    ) async throws -> [Model] {
        let operation = coreDataRepository.fetchOperation(
            by: { modelIds },
            options: options
        )
        operationQueue.addOperation(operation)

        let result: [Model] = try await extract(from: operation)
        return result
    }

    public func fetch(
        by modelId: String,
        options: RepositoryFetchOptions
    ) async throws -> Model? {
        let operation = coreDataRepository.fetchOperation(
            by: { modelId },
            options: options
        )
        operationQueue.addOperation(operation)

        let result: Model? = try await extract(from: operation)
        return result
    }

    public func fetchAll(
        with options: RepositoryFetchOptions
    ) async throws -> [Model] {
        let operation = coreDataRepository.fetchAllOperation(with: options)
        operationQueue.addOperation(operation)

        let result: [Model] = try await extract(from: operation)
        return result
    }

    public func save(
        models: [Model],
        deleteIds: [String]
    ) async {
        let operation = coreDataRepository.saveOperation(
            { models },
            { deleteIds }
        )
        operationQueue.addOperation(operation)

        let result: Void = await withCheckedContinuation { continuation in
            operation.completionBlock = {
                continuation.resume()
            }
        }
        return result
    }

    // MARK: - Private methods

    private func extract<ResultType>(
        from operation: BaseOperation<ResultType>
    ) async throws -> ResultType {
        let result: ResultType = try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                guard let result = operation.result else {
                    continuation.resume(throwing: AsyncCoreDataRepositoryError.resultNotFetched)
                    return
                }
                continuation.resume(with: result)
            }
        }
        return result
    }
}

public enum AsyncCoreDataRepositoryError: Error {
    case resultNotFetched
}
