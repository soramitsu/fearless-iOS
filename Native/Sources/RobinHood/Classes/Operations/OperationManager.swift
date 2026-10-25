/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Mode defines how to manage dependencies between in progress operations
 *  and adding ones.
 */

public enum OperationMode {
    /**
     *  Make new operations dependent on in progress operation
     *  corresponding to the identifier and barrier operation
     *  (see blockAfter mode).
     */

    case byIdentifier(_ identifier: String)

    /**
     *  Make new operations dependent on all in progress operations
     */

    case waitBefore

    /**
     *  Make adding operation dependent on barrier and become barrier itself.
     *  No operation can start executing until barrier completes.
     */

    case blockAfter

    /**
     *  Make adding operation barrier and wait until all in
     *  progress operations complete.
     */

    case sync

    /**
     *  Wait until barrier completes and start executing.
     */

    case transient
}

/**
 *  Protocol is designed to allow different services synchronize
 *  operations executing them in different modes (see ```OperationMode```).
 */

public protocol OperationManagerProtocol {
    /**
     *  Submit group operations to the queue establishing dependencies using mode.
     *
     *  - parameters:
     *      - operations: Operations to execute
     *      - mode: Operations executions mode
     */

    func enqueue(operations: [Operation], in mode: OperationMode)
}

/**
 *  Class is designed to provide implementation of ```OperationsManagerProtocol```
 *  based on ```OperationQueue```.
 */

public final class OperationManager: OperationManagerProtocol {
    private(set) var inProgressOperations: [String: [Operation]] = [:]
    private(set) var barrierOperations: [Operation] = []
    let operationQueue: OperationQueue

    private var lock: NSLock = .init()

    public init(operationQueue: OperationQueue = OperationQueue()) {
        self.operationQueue = operationQueue
    }

    public func enqueue(operations: [Operation], in mode: OperationMode) {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearCompletedOperations()

        guard !operations.isEmpty else {
            return
        }

        handleBarrier(for: operations)

        switch mode {
        case .blockAfter:
            handleBlockAfter(for: operations)
        case .waitBefore:
            handleWaitBefore(for: operations)
        case .sync:
            handleSync(for: operations)
        case let .byIdentifier(identifier):
            handle(operations: operations, for: identifier)
        case .transient:
            break
        }

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    // MARK: Private

    private func handleBarrier(for operations: [Operation]) {
        for barrierOperation in barrierOperations where !barrierOperation.isFinished {
            operations.forEach { $0.addDependency(barrierOperation) }
        }
    }

    private func handleWaitBefore(for operations: [Operation]) {
        for operation in operations {
            for pendingOperations in inProgressOperations.values {
                for pendingOperation in pendingOperations where !pendingOperation.isFinished {
                    operation.addDependency(pendingOperation)
                }
            }
        }
    }

    private func handleBlockAfter(for operations: [Operation]) {
        barrierOperations = operations
    }

    private func handleSync(for operations: [Operation]) {
        handleWaitBefore(for: operations)

        barrierOperations = operations
    }

    private func handle(operations: [Operation], for identifier: String) {
        if let currentOperations = inProgressOperations[identifier] {
            for currentOperation in currentOperations where !currentOperation.isFinished {
                operations.forEach { $0.addDependency(currentOperation) }
            }
        }

        inProgressOperations[identifier] = operations
    }

    private func clearCompletedOperations() {
        inProgressOperations = inProgressOperations
            .filter { !$0.value.allSatisfy { $0.isFinished } }
        barrierOperations = barrierOperations.filter { !$0.isFinished }
    }
}
