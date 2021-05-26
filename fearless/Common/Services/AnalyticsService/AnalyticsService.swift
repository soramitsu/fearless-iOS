import Foundation
import RobinHood
import FearlessUtils

final class AnalyticsService: Longrunable {
    typealias ResultType = [SubscanRewardItemData]

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
    let address: AccountAddress
    let url: URL
    let pageSize: Int

    private var result: ResultType = []
    private var context: Context?
    private weak var currentOperation: Operation?
    private var mutex = NSLock()

    private var state: State = .none

    private var completionClosure: ((Result<ResultType, Error>) -> Void)?

    init(
        url: URL,
        address: AccountAddress,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        pageSize: Int = 100
    ) {
        self.url = url
        self.address = address
        self.subscanOperationFactory = subscanOperationFactory
        self.operationManager = operationManager
        self.pageSize = pageSize
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
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
        let info = HistoryInfo(address: address, row: pageSize, page: page)

        let fetchOperation = subscanOperationFactory.fetchRewardsAndSlashesOperation(url, info: info)

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

    private func handlePage(response: SubscanRewardData) {
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

        let itemData = response.items ?? []
        result += itemData

        let currentPage = context?.page ?? 0
        let loadedCount = currentPage * pageSize + itemData.count

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

extension AnalyticsService {
    func longrunOperation() -> LongrunOperation<ResultType> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }
}
