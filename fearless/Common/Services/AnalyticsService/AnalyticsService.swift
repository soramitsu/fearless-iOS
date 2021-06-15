import Foundation
import RobinHood
import FearlessUtils

final class AnalyticsService: Longrunable {
    typealias ResultType = [SubqueryRewardItemData]

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

    let subqueryRewardsSource: SubqueryRewardsSource
    let operationManager: OperationManagerProtocol
    let address: AccountAddress
    let baseUrl: URL
    let pageSize: Int

    private var result: ResultType = []
    private var context: Context?
    private weak var currentOperation: Operation?
    private var mutex = NSLock()

    private var state: State = .none

    private var completionClosure: ((Result<ResultType, Error>) -> Void)?

    init(
        baseUrl: URL,
        address: AccountAddress,
        operationManager: OperationManagerProtocol,
        pageSize: Int = 100
    ) {
        let address = "12dfEn1GycUmHtfEDW3BuQYzsMyUR1PqUPH2pyEikYeUX59o"
        self.baseUrl = baseUrl
        self.address = address
        subqueryRewardsSource = SubqueryRewardsSource(address: address, url: baseUrl)
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

    private func loadNext(page _: Int) {
        // TODO: Add cursor
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global().async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.handlePage(response: response)
                } catch {
                    self?.completeWithError(error)
                }
            }
        }

        currentOperation = fetchOperation.targetOperation

        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }

    private func handlePage(response: [SubqueryRewardItemData]?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard state == .inProgress else {
            return
        }

//        if let context = context, context.totalCount != response.count {
//            completeWithError(InternalError.totalCountMismatch)
//            return
//        }

        let itemData = response ?? []
        result += itemData

        completeWithResult()
//        let currentPage = context?.page ?? 0
//        let loadedCount = currentPage * pageSize + itemData.count
//
//        if loadedCount == response.count {
//            completeWithResult()
//        } else {
//            let newContext = Context(page: currentPage + 1, totalCount: response.count)
//            context = newContext
//
//            loadNext(page: newContext.page)
//        }
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
