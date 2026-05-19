import Foundation
import RobinHood

// Minimal in-memory repository returning no items; suitable for StreamableProvider in tests
final class EmptyRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    func fetchOperation(by modelIdsClosure: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by modelIdClosure: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<T?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [T]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation { () } }
}

// No-op observable for repository changes; required by StreamableProvider
final class DummyRepositoryObservable<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_ observer: AnyObject, deliverOn queue: DispatchQueue, executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_ observer: AnyObject) {}
}

