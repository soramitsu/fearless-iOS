/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

public final class StreamableProvider<T: Identifiable> {
    let source: AnyStreamableSource<T>
    let repository: AnyDataProviderRepository<T>
    let observable: AnyDataProviderRepositoryObservable<T>
    let operationManager: OperationManagerProtocol
    let processingQueue: DispatchQueue

    var observers: [DataProviderObserver<T, StreamableProviderObserverOptions>] = []
    var pendingObservers: [DataProviderPendingObserver<[T]>] = []

    public init(
        source: AnyStreamableSource<T>,
        repository: AnyDataProviderRepository<T>,
        observable: AnyDataProviderRepositoryObservable<T>,
        operationManager: OperationManagerProtocol,
        serialQueue: DispatchQueue? = nil
    ) {
        self.source = source
        self.repository = repository
        self.observable = observable
        self.operationManager = operationManager

        if let currentProcessingQueue = serialQueue {
            processingQueue = currentProcessingQueue
        } else {
            processingQueue = DispatchQueue(
                label: "co.jp.streamableprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility
            )
        }
    }

    private func startObservingSource() {
        observable.addObserver(self, deliverOn: processingQueue) { [weak self] changes in
            self?.notifyObservers(with: changes)
        }
    }

    private func stopObservingSource() {
        observable.removeObserver(self)
    }

    private func fetchHistory(completionBlock: ((Result<Int, Error>?) -> Void)?) {
        source.fetchHistory(
            runningIn: processingQueue,
            commitNotificationBlock: completionBlock
        )
    }

    private func notifyObservers(with changes: [DataProviderChange<Model>]) {
        for observerWrapper in observers {
            if observerWrapper.observer != nil {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.updateBlock(changes)
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        for observerWrapper in observers {
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.failureBlock(error)
                }
            }
        }
    }

    private func notifyObservers(with fetchResult: Result<Int, Error>) {
        for observerWrapper in observers {
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                switch fetchResult {
                case let .success(count):
                    if count == 0 {
                        dispatchInQueueWhenPossible(observerWrapper.queue) {
                            observerWrapper.updateBlock([])
                        }
                    }
                case let .failure(error):
                    dispatchInQueueWhenPossible(observerWrapper.queue) {
                        observerWrapper.failureBlock(error)
                    }
                }
            }
        }
    }

    private func isAlreadyAdded(observer: AnyObject) -> Bool {
        pendingObservers.contains(where: { $0.observer === observer }) ||
            observers.contains(where: { $0.observer === observer })
    }

    private func completeAdd(
        observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: StreamableProviderObserverOptions
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
            let shouldObserveSource = observers.isEmpty

            observers = observers.filter { $0.observer != nil }

            let repositoryObserver = DataProviderObserver(
                observer: observer,
                queue: queue,
                updateBlock: updateBlock,
                failureBlock: failureBlock,
                options: options
            )
            observers.append(repositoryObserver)

            let updates = items.map { DataProviderChange<T>.insert(newItem: $0) }

            if !options.notifyJustWhenUpdated {            
                dispatchInQueueWhenPossible(queue) {
                    updateBlock(updates)
                }
            }

            if shouldObserveSource {
                startObservingSource()
            }

            if updates.isEmpty, options.refreshWhenEmpty {
                refresh()
            }

        case let .failure(error):
            dispatchInQueueWhenPossible(queue) {
                failureBlock(error)
            }
        }
    }
}

extension StreamableProvider: StreamableProviderProtocol {
    public typealias Model = T

    public func refresh() {
        source.refresh(runningIn: processingQueue) { [weak self] result in
            if let result = result {
                self?.notifyObservers(with: result)
            }
        }
    }

    public func fetch(
        offset: Int,
        count: Int,
        synchronized: Bool,
        with completionBlock: @escaping (Result<[Model], Error>?) -> Void
    )
        -> CompoundOperationWrapper<[Model]>
    {
        let sliceRequest = RepositorySliceRequest(offset: offset, count: count, reversed: false)
        let operation = repository.fetchOperation(by: sliceRequest)

        operation.completionBlock = { [weak self] in
            if let result = operation.result,
               case let .success(models) = result,
               models.count < count
            {
                let completionBlock: (Result<Int, Error>?) -> Void = { optionalResult in
                    if let result = optionalResult {
                        self?.notifyObservers(with: result)
                    }
                }

                self?.fetchHistory(completionBlock: completionBlock)
            }

            completionBlock(operation.result)
        }

        if synchronized {
            operationManager.enqueue(operations: [operation], in: .sync)
        } else {
            operationManager.enqueue(operations: [operation], in: .transient)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: StreamableProviderObserverOptions
    ) {
        processingQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if self.isAlreadyAdded(observer: observer) {
                dispatchInQueueWhenPossible(queue) {
                    failureBlock(DataProviderError.observerAlreadyAdded)
                }

                return
            }

            let operation: BaseOperation<[Model]>

            if options.initialSize > 0 {
                let sliceRequest = RepositorySliceRequest(
                    offset: 0,
                    count: options.initialSize,
                    reversed: false
                )

                operation = self.repository.fetchOperation(by: sliceRequest)
            } else {
                operation = self.repository.fetchAllOperation()
            }

            let pending = DataProviderPendingObserver(
                observer: observer,
                operation: operation
            )
            self.pendingObservers.append(pending)

            operation.completionBlock = {
                self.processingQueue.async {
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
                self.operationManager.enqueue(operations: [operation], in: .sync)
            } else {
                self.operationManager.enqueue(operations: [operation], in: .transient)
            }
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            if let pending = self.pendingObservers.first(where: { $0.observer === observer }) {
                pending.operation?.cancel()
            }

            self.pendingObservers = self.pendingObservers
                .filter { $0.observer != nil && $0.observer !== observer }

            let wasObservingSource = !self.observers.isEmpty
            self.observers = self.observers
                .filter { $0.observer != nil && $0.observer !== observer }

            if wasObservingSource, self.observers.isEmpty {
                self.stopObservingSource()
            }
        }
    }
}
