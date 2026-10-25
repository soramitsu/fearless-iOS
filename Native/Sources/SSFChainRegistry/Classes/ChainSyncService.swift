import Foundation
import RobinHood
import SSFLogger
import SSFModels
import SSFNetwork
import SSFUtils

public protocol ChainSyncServiceProtocol {
    func getChainModel(for chainId: ChainModel.Id) async throws -> ChainModel
    func getChainModels() async throws -> [ChainModel]
    func syncUp()
}

public enum ChainSyncServiceError: Error {
    case chainsNotLoaded
    case missingChainModel
    case invalidUrl
    case mappingError
}

public final class ChainSyncService {
    private let chainsUrl: URL
    private let dataFetchFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
    private var retryAttempt: Int = 0
    private var isSyncing: Bool = false
    private let mutex = NSLock()

    private var remoteMapping: [ChainModel.Id: ChainModel] = [:]

    public init(
        chainsUrl: URL,
        operationQueue: OperationQueue,
        dataFetchFactory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection()
    ) {
        self.chainsUrl = chainsUrl
        self.dataFetchFactory = dataFetchFactory
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
    }

    private func executeSync() async throws -> [ChainModel.Id: ChainModel] {
        mutex.withLock { retryAttempt += 1 }
        return try await fetchRemoteData(chainsUrl: chainsUrl)
    }

    private func syncChanges(remoteChains: [ChainModel]) -> [ChainModel.Id: ChainModel] {
        let remoteMapping = remoteChains
            .reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }
        complete(result: .success(remoteMapping))
        return remoteMapping
    }

    private func fetchRemoteData(chainsUrl: URL) async throws -> [ChainModel.Id: ChainModel] {
        let remoteFetchChainsOperation: BaseOperation<[ChainModel]> = dataFetchFactory
            .fetchData(from: chainsUrl)
        defer { withExtendedLifetime(remoteFetchChainsOperation) {} }

        do {
            let chains: [ChainModel] = try await withCheckedThrowingContinuation { continuation in
                remoteFetchChainsOperation.completionBlock = { [weak remoteFetchChainsOperation] in
                    guard let result = remoteFetchChainsOperation?.result else {
                        continuation.resume(throwing: BaseOperationError.parentOperationCancelled)
                        return
                    }
                    continuation.resume(with: result)
                }
                // An operation may finish immediately, so install its completion first.
                operationQueue.addOperations([remoteFetchChainsOperation], waitUntilFinished: false)
            }
            return syncChanges(remoteChains: chains)
        } catch {
            complete(result: .failure(error))
            throw error
        }
    }

    private func complete(result: Result<[ChainModel.Id: ChainModel], Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        switch result {
        case let .success(remoteMapping):
            retryAttempt = 0
            self.remoteMapping = remoteMapping
        case .failure, .none:
            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(nextDelay)
        }
    }
}

// MARK: - ChainSyncServiceProtocol

extension ChainSyncService: ChainSyncServiceProtocol {
    public func getChainModel(for chainId: ChainModel.Id) async throws -> ChainModel {
        if let chainModel = mutex.withLock({ remoteMapping[chainId] }) {
            return chainModel
        }

        let remoteMap = try await executeSync()
        guard let remoteChainModel = remoteMap[chainId] else {
            throw ChainSyncServiceError.missingChainModel
        }
        return remoteChainModel
    }

    public func getChainModels() async throws -> [ChainModel] {
        let cached = mutex.withLock { remoteMapping }
        if !cached.isEmpty {
            return Array(cached.values)
        }

        let remoteMap = try await executeSync()
        return Array(remoteMap.values)
    }

    public func syncUp() {
        Task { try await executeSync() }
    }
}

// MARK: - SchedulerDelegate

extension ChainSyncService: SchedulerDelegate {
    public func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        Task { try await executeSync() }
    }
}
