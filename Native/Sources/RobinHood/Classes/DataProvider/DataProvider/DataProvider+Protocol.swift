/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension DataProvider {
    func isAlreadyAdded(observer: AnyObject) -> Bool {
        pendingObservers.contains(where: { $0.observer === observer }) ||
            observers.contains(where: { $0.observer === observer })
    }

    private func completeAdd(
        observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: DataProviderObserverOptions
    ) {
        guard let pending = pendingObservers.first(where: { $0.observer === observer }),
              let result = pending.operation?.result else
        {
            dispatchInQueueWhenPossible(queue) {
                failureBlock(DataProviderError.dependencyCancelled)
            }

            return
        }

        pendingObservers = pendingObservers
            .filter { $0.observer != nil && $0.observer !== observer }

        switch result {
        case let .success(items):
            let repositoryObserver = DataProviderObserver(
                observer: observer,
                queue: queue,
                updateBlock: updateBlock,
                failureBlock: failureBlock,
                options: options
            )
            observers.append(repositoryObserver)

            updateTrigger.receive(event: .addObserver(observer))

            let updates = items.map { DataProviderChange<T>.insert(newItem: $0) }

            dispatchInQueueWhenPossible(queue) {
                updateBlock(updates)
            }
        case let .failure(error):
            dispatchInQueueWhenPossible(queue) {
                failureBlock(error)
            }
        }
    }
}

extension DataProvider: DataProviderProtocol {
    public func fetch(
        by modelId: String,
        completionBlock: ((Result<T?, Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<T?>
    {
        let repositoryOperation = repository.fetchOperation(by: modelId)
        let sourceWrapper = source.fetchOperation(by: modelId)

        let sourceCancellationOperation = ClosureOperation<T?> {
            if let optionalModel = try repositoryOperation.extractResultData(),
               let result = optionalModel
            {
                sourceWrapper.cancel()
                return result
            } else {
                return nil
            }
        }

        sourceCancellationOperation.addDependency(repositoryOperation)

        for operation in sourceWrapper.allOperations {
            operation.addDependency(sourceCancellationOperation)
        }

        let reduceOperation = ClosureOperation<T?> {
            if let optionalModel = try repositoryOperation.extractResultData(),
               let result = optionalModel
            {
                return result
            }

            if let optionalModel = try sourceWrapper.targetOperation.extractResultData(),
               let result = optionalModel
            {
                return result
            }

            throw BaseOperationError.parentOperationCancelled
        }

        reduceOperation.addDependency(sourceWrapper.targetOperation)

        reduceOperation.completionBlock = {
            completionBlock?(reduceOperation.result)
        }

        let dependencies = [repositoryOperation, sourceCancellationOperation] + sourceWrapper
            .allOperations

        let wrapper = CompoundOperationWrapper(
            targetOperation: reduceOperation,
            dependencies: dependencies
        )

        executionQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        updateTrigger.receive(event: .fetchById(modelId))

        return wrapper
    }

    public func fetch(
        page index: UInt,
        completionBlock: ((Result<[Model], Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<[Model]>
    {
        if index > 0 {
            let sourceWrapper = source.fetchOperation(page: index)

            sourceWrapper.targetOperation.completionBlock = {
                completionBlock?(sourceWrapper.targetOperation.result)
            }

            executionQueue.addOperations(sourceWrapper.allOperations, waitUntilFinished: false)

            updateTrigger.receive(event: .fetchPage(index))

            return sourceWrapper
        }

        let repositoryOperation = repository.fetchAllOperation()
        let sourceWrapper = source.fetchOperation(page: 0)

        let sourceCancellationOperation = ClosureOperation<[T]> {
            if let result = try repositoryOperation.extractResultData(), !result.isEmpty {
                sourceWrapper.cancel()
                return result
            } else {
                return []
            }
        }

        sourceCancellationOperation.addDependency(repositoryOperation)

        for operation in sourceWrapper.allOperations {
            operation.addDependency(sourceCancellationOperation)
        }

        let reduceOperation = ClosureOperation<[T]> {
            if let result = try sourceCancellationOperation.extractResultData(), !result.isEmpty {
                return result
            }

            if let result = try sourceWrapper.targetOperation.extractResultData() {
                return result
            }

            throw BaseOperationError.parentOperationCancelled
        }

        reduceOperation.addDependency(sourceWrapper.targetOperation)

        reduceOperation.completionBlock = {
            completionBlock?(reduceOperation.result)
        }

        let dependencies = [repositoryOperation, sourceCancellationOperation] + sourceWrapper
            .allOperations

        let wrapper = CompoundOperationWrapper(
            targetOperation: reduceOperation,
            dependencies: dependencies
        )

        executionQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        updateTrigger.receive(event: .fetchPage(index))

        return wrapper
    }

    public func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: DataProviderObserverOptions
    ) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if self.isAlreadyAdded(observer: observer) {
                dispatchInQueueWhenPossible(queue) {
                    failureBlock(DataProviderError.observerAlreadyAdded)
                }
                return
            }

            let repositoryOperation = self.repository.fetchAllOperation()

            let pending = DataProviderPendingObserver(
                observer: observer,
                operation: repositoryOperation
            )
            self.pendingObservers.append(pending)

            repositoryOperation.completionBlock = {
                self.syncQueue.async {
                    self.completeAdd(
                        observer: observer,
                        deliverOn: queue,
                        executing: updateBlock,
                        failing: failureBlock,
                        options: options
                    )
                }
            }

            if options.waitsInProgressSyncOnAdd {
                if let syncOperation = self.lastSyncOperation, !syncOperation.isFinished {
                    repositoryOperation.addDependency(syncOperation)
                }

                self.lastSyncOperation = repositoryOperation
            }

            self.executionQueue.addOperations([repositoryOperation], waitUntilFinished: false)
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        syncQueue.async {
            if let pending = self.pendingObservers.first(where: { $0.observer === observer }) {
                pending.operation?.cancel()
            }

            self.pendingObservers = self.pendingObservers
                .filter { $0.observer != nil && $0.observer !== observer }

            self.observers = self.observers
                .filter { $0.observer !== observer && $0.observer != nil }

            self.updateTrigger.receive(event: .removeObserver(observer))
        }
    }

    public func refresh() {
        dispatchUpdateRepository()
    }
}
