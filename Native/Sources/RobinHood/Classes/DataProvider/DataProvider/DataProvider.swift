/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Implementation of `DataProviderProtocol` is designed to satify defined requirements of the protocol
 *  and to be first consideration when there is a need to cache a list of remote objects.
 *
 *  Besides methods defined in protocol the implementation provides an ability to control when
 *  synchronization executes requiring special trigger object to be passed
 *  during initialization (see `DataProviderTriggerProtocol`).
 */

public final class DataProvider<T: Identifiable & Equatable> {
    public typealias Model = T

    /// Type erased implementation of `DataProviderRepositoryProtocol` that manages local storage.
    public private(set) var repository: AnyDataProviderRepository<T>

    /// Type erased implementation of `DataProviderRepositoryProtocol` that manages local storage.
    public private(set) var source: AnyDataProviderSource<T>

    /// Implementation of `DataProviderTriggerProtocol` protocol to trigger objects synchronization.
    public private(set) var updateTrigger: DataProviderTriggerProtocol

    /// Operation queue to execute internal operations.
    public private(set) var executionQueue: OperationQueue

    /// Serial dispatch queue to use as synchronization primitive internally.
    public private(set) var syncQueue: DispatchQueue

    var observers: [DataProviderObserver<T, DataProviderObserverOptions>] = []
    var pendingObservers: [DataProviderPendingObserver<[T]>] = []
    weak var lastSyncOperation: Operation?
    weak var repositoryUpdateOperation: Operation?

    /**
     *  Creates data provider object.
     *
     *  - parameters:
     *    - source: Type erased implementation of `DataProviderSourceProtocol` that controls fetching data
     *      from remote source.
     *    - repository: Type erased implementation of `DataProviderRepositoryProtocol` that manages local storage.
     *    - updateTrigger: Implementation of `DataProviderTriggerProtocol` protocol.
     *      By default `DataProviderEventTrigger.onAll` is passed which means that synchronization is triggered
     *      after each access to public methods including constructor.
     *    - executionQueue: Operation queue to execute internal operations. Pass `nil` (default) to create
     *      new operation queue. However, sometimes, it is convienent to share operation queue to take advantage
     *      of chaining and dependency features.
     *    - serialSyncQueue: Serial dispatch queue to use as synchronization primitive internally.
     *      Usually, this parameter should be ignored which creates new synchronization queue (with utility QOS class)
     *      but sometimes there is a need to share a global queue due to optimization reasons.
     */

    public init(
        source: AnyDataProviderSource<T>,
        repository: AnyDataProviderRepository<T>,
        updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
        executionQueue: OperationQueue? = nil,
        serialSyncQueue: DispatchQueue? = nil
    ) {
        self.source = source
        self.repository = repository

        if let currentExecutionQueue = executionQueue {
            self.executionQueue = currentExecutionQueue
        } else {
            self.executionQueue = OperationQueue()
        }

        if let currentSyncQueue = serialSyncQueue {
            syncQueue = currentSyncQueue
        } else {
            syncQueue = DispatchQueue(
                label: "co.jp.dataprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility
            )
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self
        self.updateTrigger.receive(event: .initialization)
    }
}

// MARK: Internal Repository update logic

extension DataProvider {
    func dispatchUpdateRepository() {
        syncQueue.async {
            self.updateRepository()
        }
    }

    private func updateRepository() {
        if let currentUpdateRepositoryOperation = repositoryUpdateOperation,
           !currentUpdateRepositoryOperation.isFinished
        {
            return
        }

        let sourceWrapper = source.fetchOperation(page: 0)

        let repositoryOperation = repository.fetchAllOperation()

        let differenceOperation = createDifferenceOperation(
            dependingOn: sourceWrapper.targetOperation,
            repositoryOperation: repositoryOperation
        )

        let saveOperation = createSaveRepositoryOperation(dependingOn: differenceOperation)

        saveOperation.completionBlock = {
            guard let saveResult = saveOperation.result else {
                return
            }

            if case let .failure(error) = saveResult {
                self.syncQueue.async {
                    self.notifyObservers(with: error)
                }

                return
            }

            guard let changesResult = differenceOperation.result,
                  case let .success(updates) = changesResult else
            {
                return
            }

            self.syncQueue.async {
                self.notifyObservers(with: updates)
            }
        }

        repositoryUpdateOperation = saveOperation

        if let syncOperation = lastSyncOperation, !syncOperation.isFinished {
            sourceWrapper.allOperations.forEach { $0.addDependency(syncOperation) }
            repositoryOperation.addDependency(syncOperation)
        }

        lastSyncOperation = saveOperation

        let operations = sourceWrapper.allOperations + [
            repositoryOperation,
            differenceOperation,
            saveOperation,
        ]

        executionQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func createDifferenceOperation(
        dependingOn sourceOperation: BaseOperation<[T]>,
        repositoryOperation: BaseOperation<[T]>
    )
        -> BaseOperation<[DataProviderChange<T>]>
    {
        let operation = ClosureOperation<[DataProviderChange<T>]> {
            guard let sourceResult = sourceOperation.result else {
                throw DataProviderError.unexpectedSourceResult
            }

            if case let .failure(error) = sourceResult {
                throw error
            }

            guard let repositoryResult = repositoryOperation.result else {
                throw DataProviderError.unexpectedRepositoryResult
            }

            if case let .failure(error) = repositoryResult {
                throw error
            }

            if case let .success(sourceModels) = sourceResult,
               case let .success(repositoryModels) = repositoryResult
            {
                return try self.findChanges(
                    sourceResult: sourceModels,
                    repositoryResult: repositoryModels
                )
            } else {
                throw DataProviderError.unexpectedSourceResult
            }
        }

        operation.addDependency(sourceOperation)
        operation.addDependency(repositoryOperation)

        return operation
    }

    private func createSaveRepositoryOperation(
        dependingOn differenceOperation: BaseOperation<[DataProviderChange<T>]>
    )
        -> BaseOperation<Void>
    {
        let updatedItemsBlock = { () throws -> [T] in
            guard let result = differenceOperation.result else {
                throw DataProviderError.dependencyCancelled
            }

            switch result {
            case let .success(updates):
                return updates.compactMap { update in
                    update.item
                }
            case let .failure(error):
                throw error
            }
        }

        let deletedItemsBlock = { () throws -> [String] in
            guard let result = differenceOperation.result else {
                throw DataProviderError.dependencyCancelled
            }

            switch result {
            case let .success(updates):
                return updates.compactMap { item in
                    if case let .delete(identifier) = item {
                        return identifier
                    } else {
                        return nil
                    }
                }
            case let .failure(error):
                throw error
            }
        }

        let operation = repository.saveOperation(updatedItemsBlock, deletedItemsBlock)

        operation.addDependency(differenceOperation)

        return operation
    }

    private func notifyObservers(with updates: [DataProviderChange<T>]) {
        for repositoryObserver in observers {
            if repositoryObserver.observer != nil,
               !updates.isEmpty || repositoryObserver.options.alwaysNotifyOnRefresh
            {
                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    repositoryObserver.updateBlock(updates)
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        for repositoryObserver in observers {
            if repositoryObserver.observer != nil,
               repositoryObserver.options.alwaysNotifyOnRefresh
            {
                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    repositoryObserver.failureBlock(error)
                }
            }
        }
    }

    private func findChanges(
        sourceResult: [T],
        repositoryResult: [T]
    ) throws -> [DataProviderChange<T>] {
        let sourceKeyValue = sourceResult.reduce(into: [String: T]()) { result, item in
            result[item.identifier] = item
        }

        let repositoryKeyValue = repositoryResult.reduce(into: [String: T]()) { result, item in
            result[item.identifier] = item
        }

        var updates: [DataProviderChange<T>] = []

        for sourceModel in sourceResult {
            if let repositoryModel = repositoryKeyValue[sourceModel.identifier] {
                if sourceModel != repositoryModel {
                    updates.append(DataProviderChange.update(newItem: sourceModel))
                }

            } else {
                updates.append(DataProviderChange.insert(newItem: sourceModel))
            }
        }

        for repositoryModel in repositoryResult
            where sourceKeyValue[repositoryModel.identifier] == nil
        {
            updates.append(DataProviderChange.delete(deletedIdentifier: repositoryModel.identifier))
        }

        return updates
    }
}
