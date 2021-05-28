import Foundation
import RobinHood
import FearlessUtils

final class StorageKeysQueryService<T>: Longrunable {
    typealias ResultType = [T]

    enum State {
        case none
        case inProgress(partialResult: [T], lastKey: String?)
        case completed(result: [T])
    }

    enum InternalError: Error {
        case alreadyRunning
        case cancelled
    }

    let connection: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let pageSize: UInt32
    let prefixKeyClosure: () throws -> Data
    let mapper: AnyMapper<Data, T>

    private var state: State = .none
    private var completionClosure: ((Result<ResultType, Error>) -> Void)?
    private weak var currentOperation: Operation?
    private var mutex = NSLock()

    init(
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        prefixKeyClosure: @escaping () throws -> Data,
        mapper: AnyMapper<Data, T>,
        pageSize: UInt32 = 1000
    ) {
        self.connection = connection
        self.operationManager = operationManager
        self.prefixKeyClosure = prefixKeyClosure
        self.pageSize = pageSize
        self.mapper = mapper
    }

    private func loadNext() {
        guard case let .inProgress(_, lastKey) = state else {
            return
        }

        do {
            let prefixKey = try prefixKeyClosure()

            let request = PagedKeysRequest(
                key: prefixKey.toHex(includePrefix: true),
                count: pageSize,
                offset: lastKey.map { $0 }
            )

            let operation = JSONRPCOperation<PagedKeysRequest, [String]>(
                engine: connection,
                method: RPCMethod.getStorageKeysPaged,
                parameters: request
            )

            currentOperation = operation

            operation.completionBlock = { [weak self] in
                DispatchQueue.global().async {
                    do {
                        let response = try operation.extractNoCancellableResultData()
                        self?.handlePage(response: response)
                    } catch {
                        self?.completeWithError(error)
                    }
                }
            }

            operationManager.enqueue(operations: [operation], in: .transient)

        } catch {
            completeWithError(error)
        }
    }

    private func handlePage(response: [String]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard case let .inProgress(oldItems, _) = state else {
            return
        }

        do {
            let mappedItems: [T] = try response.map { hexKey in
                let keyData = try Data(hexString: hexKey)
                return mapper.map(input: keyData)
            }

            let resultItems = oldItems + mappedItems

            if mappedItems.count < pageSize {
                completeWithResult(resultItems)
            } else {
                state = .inProgress(partialResult: resultItems, lastKey: response.last)
                loadNext()
            }
        } catch {
            completeWithError(error)
        }
    }

    private func completeWithResult(_ result: [T]) {
        let closure = completionClosure

        completionClosure = nil
        state = .completed(result: result)

        closure?(.success(result))
    }

    private func completeWithError(_ error: Error) {
        let closure = completionClosure

        completionClosure = nil
        state = .completed(result: [])

        closure?(.failure(error))
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard case .none = state else {
            completionClosure(.failure(InternalError.alreadyRunning))
            return
        }

        state = .inProgress(partialResult: [], lastKey: nil)
        self.completionClosure = completionClosure

        loadNext()
    }

    func cancel() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard case .inProgress = state else {
            return
        }

        completeWithError(InternalError.cancelled)
    }
}

extension StorageKeysQueryService {
    func longrunOperation() -> LongrunOperation<[T]> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }
}
