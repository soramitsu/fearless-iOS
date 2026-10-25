/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Structure is designed to represent universal swift model for single object to
 *  pass and receive from repository.
 */

public struct SingleValueProviderObject: Identifiable & Codable {
    /// Identifier of the object
    public var identifier: String

    /// serialized object's data
    public var payload: Data

    public init(identifier: String, payload: Data) {
        self.identifier = identifier
        self.payload = payload
    }
}

/**
 *  Implementation of `SingleValueProviderProtocol` is designed to satify defined requirements of the protocol
 *  and to be first consideration when there is a need to cache a remote object.
 *
 *  Besides methods defined in protocol the implementation provides an ability to control when
 *  synchronization executes requiring special trigger object to be passed
 *  during initialization (see `DataProviderTriggerProtocol`).
 */

public final class SingleValueProvider<T: Codable & Equatable> {
    public typealias Model = T

    /// Type erased implementation of `DataProviderRepositoryProtocol` that manages local storage.
    public private(set) var repository: AnyDataProviderRepository<SingleValueProviderObject>

    /// Type erased implementation of `SingleValueProviderSourceProtocol` that controls fetching
    /// data
    /// from remote source.
    public private(set) var source: AnySingleValueProviderSource<T>

    /// Implementation of `DataProviderTriggerProtocol` protocol.
    public private(set) var updateTrigger: DataProviderTriggerProtocol

    /// Operation queue to execute internal operations.
    public private(set) var executionQueue: OperationQueue

    /// Serial dispatch queue to use as synchronization primitive internally.
    public private(set) var syncQueue: DispatchQueue

    /// Identifier of the object to manage.
    public private(set) var targetIdentifier: String

    /// Encoder to serialize value for storage

    public lazy var encoder = JSONEncoder()

    /// Decoder to deserialize value from storage

    public lazy var decoder = JSONDecoder()

    var observers: [DataProviderObserver<T, DataProviderObserverOptions>] = []
    var pendingObservers: [DataProviderPendingObserver<SingleValueProviderObject?>] = []
    weak var lastSyncOperation: Operation?
    weak var repositoryUpdateOperation: Operation?

    /**
     *  Creates data provider object.
     *
     *  - parameters:
     *    - targetIdentifier: Identifier of the object to manage.
     *    - source: Type erased implementation of `SingleValueProviderSourceProtocol` that controls fetching data
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
        targetIdentifier: String,
        source: AnySingleValueProviderSource<T>,
        repository: AnyDataProviderRepository<SingleValueProviderObject>,
        updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
        executionQueue: OperationQueue? = nil,
        serialSyncQueue: DispatchQueue? = nil
    ) {
        self.targetIdentifier = targetIdentifier
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
                label: "co.jp.singlevalueprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility
            )
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self
        self.updateTrigger.receive(event: .initialization)
    }
}

// MARK: Internal Repository update logic implementation

extension SingleValueProvider {
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

        let sourceWrapper = source.fetchOperation()

        let repositoryOperation = repository.fetchOperation(by: targetIdentifier)

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
                  case let .success(optionalUpdate) = changesResult else
            {
                return
            }

            self.syncQueue.async {
                self.notifyObservers(with: optionalUpdate)
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
        dependingOn sourceOperation: BaseOperation<T?>,
        repositoryOperation: BaseOperation<SingleValueProviderObject?>
    )
        -> BaseOperation<DataProviderChange<T>?>
    {
        let operation = ClosureOperation<DataProviderChange<T>?> {
            guard let sourceResult = sourceOperation.result else {
                throw DataProviderError.unexpectedSourceResult
            }

            if case let .failure(error) = sourceResult {
                throw error
            }

            guard let repositoryResult = repositoryOperation.result else {
                throw DataProviderError.unexpectedSourceResult
            }

            if case let .failure(error) = repositoryResult {
                throw error
            }

            if case let .success(sourceModel) = sourceResult,
               case let .success(repositoryModel) = repositoryResult
            {
                return try self.findChanges(
                    sourceResult: sourceModel,
                    repositoryResult: repositoryModel
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
        dependingOn differenceOperation: BaseOperation<DataProviderChange<T>?>
    )
        -> BaseOperation<Void>
    {
        let itemIdentifier = targetIdentifier

        let updatedItemsBlock = { () throws -> [SingleValueProviderObject] in
            guard let result = differenceOperation.result else {
                throw DataProviderError.dependencyCancelled
            }

            switch result {
            case let .success(optionalUpdate):
                if let update = optionalUpdate, let item = update.item {
                    let payload = try self.encoder.encode(item)
                    let singleValueObject = SingleValueProviderObject(
                        identifier: itemIdentifier,
                        payload: payload
                    )
                    return [singleValueObject]
                } else {
                    return []
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
            case let .success(optionalUpdate):
                if let update = optionalUpdate, case .delete = update {
                    return [itemIdentifier]
                } else {
                    return []
                }
            case let .failure(error):
                throw error
            }
        }

        let operation = repository.saveOperation(updatedItemsBlock, deletedItemsBlock)

        operation.addDependency(differenceOperation)

        return operation
    }

    private func notifyObservers(with update: DataProviderChange<T>?) {
        for repositoryObserver in observers {
            if repositoryObserver.observer != nil,
               update != nil || repositoryObserver.options.alwaysNotifyOnRefresh
            {
                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    if let update = update {
                        repositoryObserver.updateBlock([update])
                    } else {
                        repositoryObserver.updateBlock([])
                    }
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

    private func findChanges(sourceResult: T?, repositoryResult: SingleValueProviderObject?) throws
        -> DataProviderChange<T>?
    {
        guard let existingSourceResult = sourceResult else {
            if repositoryResult != nil {
                // no source data or broken, just remove inconsistent local data
                return DataProviderChange.delete(deletedIdentifier: targetIdentifier)
            } else {
                return nil
            }
        }

        guard let existingRepositoryResult = repositoryResult else {
            // new data received and no local data, so insert new one
            return DataProviderChange.insert(newItem: existingSourceResult)
        }

        guard let existingLocalValue = try? decoder.decode(
            T.self,
            from: existingRepositoryResult.payload
        ) else {
            // local data is broken but remote one is ok, so just update local one
            return DataProviderChange.update(newItem: existingSourceResult)
        }

        if existingSourceResult != existingLocalValue {
            // remote data change so update local one
            return DataProviderChange.update(newItem: existingSourceResult)
        } else {
            return nil
        }
    }
}
