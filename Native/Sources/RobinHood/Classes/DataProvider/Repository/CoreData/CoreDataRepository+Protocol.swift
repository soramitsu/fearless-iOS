/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension CoreDataRepository: DataProviderRepositoryProtocol {
    public func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(
                by: modelIdsClosure,
                options: options,
                runCompletionIn: nil
            ) { optionalModels, optionalError in
                models = optionalModels
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingModels = models {
                return existingModels
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation {
            var model: Model?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(
                by: modelIdClosure,
                options: options,
                runCompletionIn: nil
            ) { optionalModel, optionalError in
                model = optionalModel
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingModel = model {
                return existingModel
            }

            if let existingError = error {
                throw existingError
            }

            return nil
        }
    }

    public func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchAll(
                with: options,
                runCompletionIn: nil
            ) { optionalModels, optionalError in
                models = optionalModels
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingModels = models {
                return existingModels
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func fetchOperation(
        by request: RepositorySliceRequest,
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(
                request: request,
                options: options,
                runCompletionIn: nil
            ) { optionalModels, optionalError in
                models = optionalModels
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingModels = models {
                return existingModels
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    )
        -> BaseOperation<Void>
    {
        ClosureOperation {
            var error: Error?

            let updatedModels = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            if updatedModels.isEmpty, deletedIds.isEmpty {
                return
            }

            let semaphore = DispatchSemaphore(value: 0)

            self.save(
                updating: updatedModels,
                deleting: deletedIds,
                runCompletionIn: nil
            ) { optionalError in
                error = optionalError
                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }

    public func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [T],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            var error: Error?

            let updatedModels = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            if updatedModels.isEmpty, deletedIds.isEmpty {
                return
            }

            let semaphore = DispatchSemaphore(value: 0)

            self.saveBatch(
                updating: updatedModels,
                deleting: deletedIds,
                runCompletionIn: nil
            ) { optionalError in
                error = optionalError
                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }

    public func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model])
        -> BaseOperation<Void>
    {
        ClosureOperation {
            var error: Error?

            let models = try newModelsBlock()

            let semaphore = DispatchSemaphore(value: 0)

            self.replace(with: models, runCompletionIn: nil) { optionalError in
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }

    public func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation {
            var count: Int?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchCount(runCompletionIn: nil) { optionalCount, optionalError in
                count = optionalCount
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let count = count {
                return count
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.deleteAll(runCompletionIn: nil) { optionalError in
                error = optionalError
                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }
}
