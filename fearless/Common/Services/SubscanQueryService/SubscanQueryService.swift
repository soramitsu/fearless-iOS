import Foundation
import RobinHood
import FearlessUtils

final class SubscanQueryService<T, R>: Longrunable {
    typealias ResultType = R

    enum InternalError: Error {
        case totalCountMismatch
        case alreadyRunning
        case cancelled
    }

    struct Context {
        let page: Int
        let totalCount: Int
    }

    enum State {
        case none
        case inProgress
        case completed
    }

    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let params: SubscanQueryParams
    let url: URL
    let mapper: AnyMapper<JSON, T>
    let reducer: AnyReducer<T, R>
    let pageSize: Int

    private var result: R
    private var context: Context?
    private weak var currentOperation: Operation?
    private var mutex = NSLock()

    private var state: State = .none

    private var completionClosure: ((Result<R, Error>) -> Void)?

    init(
        url: URL,
        params: SubscanQueryParams,
        mapper: AnyMapper<JSON, T>,
        reducer: AnyReducer<T, R>,
        initialResultValue: R,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        pageSize: Int = 100
    ) {
        self.url = url
        self.params = params
        self.mapper = mapper
        self.reducer = reducer
        result = initialResultValue
        self.subscanOperationFactory = subscanOperationFactory
        self.operationManager = operationManager
        self.pageSize = pageSize
    }

    func start(with completionClosure: @escaping (Result<R, Error>) -> Void) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard state == .none else {
            completionClosure(.failure(InternalError.alreadyRunning))
            return
        }

        state = .inProgress
        self.completionClosure = completionClosure

        loadNext(page: 0)
    }

    func cancel() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard state == .inProgress else {
            return
        }

        completeWithError(InternalError.cancelled)
    }

    private func loadNext(page: Int) {
        let info = ExtrinsicsInfo(
            row: pageSize,
            page: page,
            address: params.address,
            moduleName: params.moduleName,
            callName: params.callName
        )

        let fetchOperation = subscanOperationFactory.fetchRawExtrinsicsOperation(url, info: info)

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.global().async {
                do {
                    let response = try fetchOperation.extractNoCancellableResultData()
                    self?.handlePage(response: response)
                } catch {
                    self?.completeWithError(error)
                }
            }
        }

        currentOperation = fetchOperation

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    private func handlePage(response: SubscanRawExtrinsicsData) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard state == .inProgress else {
            return
        }

        if let context = context, context.totalCount != response.count {
            completeWithError(InternalError.totalCountMismatch)
            return
        }

        let mappedValues = (response.extrinsics ?? []).map { mapper.map(input: $0) }
        result = reducer.reduce(list: mappedValues, initialValue: result)

        let currentPage = context?.page ?? 0
        let loadedCount = currentPage * pageSize + (response.extrinsics?.count ?? 0)

        if loadedCount == response.count {
            completeWithResult()
        } else {
            let newContext = Context(page: currentPage + 1, totalCount: response.count)
            context = newContext

            loadNext(page: newContext.page)
        }
    }

    private func completeWithResult() {
        let closure = completionClosure

        completionClosure = nil
        state = .completed

        closure?(.success(result))
    }

    private func completeWithError(_ error: Error) {
        let closure = completionClosure

        completionClosure = nil
        state = .completed

        closure?(.failure(error))
    }
}

extension SubscanQueryService {
    func longrunOperation() -> LongrunOperation<R> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }
}
