import Foundation
import RobinHood

enum OperationCombiningServiceError: Error {
    case alreadyRunningOrFinished
}

final class OperationCombiningService<T>: Longrunable {
    enum State {
        case waiting
        case running
        case finished
    }

    typealias ResultType = [T]

    let operationsClosure: () throws -> [CompoundOperationWrapper<T>]
    let operationManager: OperationManagerProtocol
    let operationsPerBatch: Int

    private let stateLock = NSLock()
    private var storedState: State = .waiting
    private var operations: [Operation] = []

    var state: State {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedState
    }

    init(
        operationManager: OperationManagerProtocol,
        operationsPerBatch: Int = 0,
        operationsClosure: @escaping () throws -> [CompoundOperationWrapper<T>]
    ) {
        self.operationManager = operationManager
        self.operationsClosure = operationsClosure
        self.operationsPerBatch = operationsPerBatch
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        stateLock.lock()
        guard storedState == .waiting else {
            stateLock.unlock()
            completionClosure(.failure(OperationCombiningServiceError.alreadyRunningOrFinished))
            return
        }
        storedState = .running
        stateLock.unlock()

        do {
            let wrappers = try operationsClosure()

            if operationsPerBatch > 0, wrappers.count > operationsPerBatch {
                for index in operationsPerBatch ..< wrappers.count {
                    let prevBatchIndex = index / operationsPerBatch - 1

                    let prevStart = prevBatchIndex * operationsPerBatch
                    let prevEnd = (prevBatchIndex + 1) * operationsPerBatch

                    for prevIndex in prevStart ..< prevEnd {
                        wrappers[index].addDependency(wrapper: wrappers[prevIndex])
                    }
                }
            }

            let mapOperation = ClosureOperation<ResultType> {
                try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
            }

            mapOperation.completionBlock = { [weak self] in
                self?.finish()

                do {
                    let result = try mapOperation.extractNoCancellableResultData()
                    completionClosure(.success(result))
                } catch {
                    completionClosure(.failure(error))
                }
            }

            let dependencies = wrappers.flatMap(\.allOperations)
            dependencies.forEach { mapOperation.addDependency($0) }

            let pendingOperations = dependencies + [mapOperation]
            stateLock.lock()
            guard storedState == .running else {
                stateLock.unlock()
                // The synchronous factory may finish after cancellation. None of
                // its newly returned work may escape into the operation queue.
                mapOperation.completionBlock = nil
                pendingOperations.forEach { $0.cancel() }
                completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                return
            }
            operations = pendingOperations
            stateLock.unlock()

            // Cancellation after publication cancels this exact set, including
            // the result operation, even if enqueue has not happened yet.
            operationManager.enqueue(operations: pendingOperations, in: .transient)

        } catch {
            finish()
            completionClosure(.failure(error))
        }
    }

    func cancel() {
        stateLock.lock()
        let pendingOperations = operations
        operations = []
        storedState = .finished
        stateLock.unlock()
        pendingOperations.forEach { $0.cancel() }
    }

    private func finish() {
        stateLock.lock()
        operations = []
        storedState = .finished
        stateLock.unlock()
    }
}

extension OperationCombiningService {
    func longrunOperation() -> LongrunOperation<[T]> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }
}
