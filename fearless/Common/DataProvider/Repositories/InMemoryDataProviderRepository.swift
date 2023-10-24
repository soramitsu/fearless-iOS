import Foundation
import RobinHood

enum InMemoryDataProviderRepositoryError: Error {
    case unsupported
}

final class InMemoryDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options _: RobinHood.RepositoryFetchOptions
    ) -> RobinHood.BaseOperation<[T]> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let modelIds = try modelIdsClosure()
            return self?.itemsById.filter { modelIds.contains($0.key) }.compactMap { $0.value } ?? []
        }
    }

    typealias Model = T

    private var itemsById: [String: Model] = [:]
    private let lock = NSLock()

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let modelId = try modelIdClosure()
            return self?.itemsById[modelId]
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            guard let values = self?.itemsById.values else {
                return []
            }

            return Array(values)
        }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        BaseOperation.createWithError(InMemoryDataProviderRepositoryError.unsupported)
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try updateModelsBlock()

            var items = self?.itemsById ?? [:]

            for model in models {
                items[model.identifier] = model
            }

            let deletedIds = try deleteIdsBlock()

            for deletedId in deletedIds {
                items[deletedId] = nil
            }

            self?.itemsById = items
        }
    }

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [T],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> RobinHood.BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try newModelsBlock()

            let newItems = models.reduce(into: [String: Model]()) { result, model in
                result[model.identifier] = model
            }

            self?.itemsById = newItems
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            return self?.itemsById.count ?? 0
        }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            self?.itemsById = [:]
        }
    }
}
