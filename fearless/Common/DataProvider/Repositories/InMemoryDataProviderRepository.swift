import Foundation
import RobinHood

enum InMemoryDataProviderRepositoryError: Error {
    case unsupported
}

final class InMemoryDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    private var items: [String: Model] = [:]
    private var lock = NSLock()

    func fetchOperation(by modelId: String,
                        options: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            return self?.items[modelId]
        }
    }

    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            guard let values = self?.items.values else {
                return []
            }

            return Array(values)
        }
    }

    func fetchOperation(by request: RepositorySliceRequest,
                        options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        BaseOperation.createWithError(InMemoryDataProviderRepositoryError.unsupported)
    }

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                       _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try updateModelsBlock()

            var items = self?.items ?? [:]

            for model in models {
                items[model.identifier] = model
            }

            let deletedIds = try deleteIdsBlock()

            for deletedId in deletedIds {
                items[deletedId] = nil
            }

            self?.items = items
        }
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try newModelsBlock()

            let newItems = models.reduce(into: [String: Model]()) { (result, model) in
                result[model.identifier] = model
            }

            self?.items = newItems
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            return self?.items.count ?? 0
        }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            self?.items = [:]
        }
    }
}
