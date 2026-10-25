/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension SingleValueProvider {
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
        case let .success(optionalEntity):
            let repositoryObserver = DataProviderObserver(
                observer: observer,
                queue: queue,
                updateBlock: updateBlock,
                failureBlock: failureBlock,
                options: options
            )
            observers.append(repositoryObserver)

            updateTrigger.receive(event: .addObserver(observer))

            var updates: [DataProviderChange<T>] = []

            if let entity = optionalEntity,
               let model = try? decoder.decode(T.self, from: entity.payload)
            {
                updates.append(DataProviderChange.insert(newItem: model))
            }

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

extension SingleValueProvider: SingleValueProviderProtocol {
    public func fetch(with completionBlock: ((Result<T?, Error>?) -> Void)?)
        -> CompoundOperationWrapper<T?>
    {
        let repositoryOperation = repository.fetchOperation(by: targetIdentifier)

        let sourceWrapper = source.fetchOperation()

        let sourceCancellationOperation = ClosureOperation<T?> {
            if let optionalEntity = try repositoryOperation.extractResultData(),
               let entity = optionalEntity,
               let model = try? self.decoder.decode(T.self, from: entity.payload)
            {
                sourceWrapper.cancel()
                return model
            } else {
                return nil
            }
        }

        sourceCancellationOperation.addDependency(repositoryOperation)

        for operation in sourceWrapper.allOperations {
            operation.addDependency(sourceCancellationOperation)
        }

        let reduceOperation = ClosureOperation<T?> {
            if let optionalModel = try sourceCancellationOperation.extractResultData(),
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

        updateTrigger.receive(event: .fetchById(targetIdentifier))

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

            let repositoryOperation = self.repository.fetchOperation(by: self.targetIdentifier)

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
