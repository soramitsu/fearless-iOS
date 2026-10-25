import Foundation
import RobinHood
import SSFModels
import SSFNetwork
import SSFUtils

public enum ChainsTypesSyncError: Error {
    case missingChainId
    case missingData
    case incorrectUrl
}

public protocol ChainsTypesSyncServiceProtocol {
    func syncUp()
    func getTypes(for chainId: ChainModel.Id) async throws -> Data
}

public final class ChainsTypesSyncService {
    private let url: URL?
    private let dataOperationFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private var isSyncing: Bool = false
    private var retryAttempt: Int = 0

    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = .init(with: self, callbackQueue: DispatchQueue.global())

    private var versioningMap: [String: Data] = [:]

    public init(
        url: URL?,
        dataOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection()
    ) {
        self.url = url
        self.dataOperationFactory = dataOperationFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            return
        }

        isSyncing = true
        Task {
            try await fetchRemoteData()
        }
    }

    private func fetchRemoteData() async throws -> [String: Data] {
        guard let url = url else {
            throw ChainsTypesSyncError.incorrectUrl
        }

        let fetchOperation: BaseOperation<JSON> = dataOperationFactory.fetchData(from: url)
        defer { withExtendedLifetime(fetchOperation) {} }

        do {
            let json: JSON = try await withCheckedThrowingContinuation { continuation in
                fetchOperation.completionBlock = { [weak fetchOperation] in
                    guard let result = fetchOperation?.result else {
                        continuation.resume(throwing: BaseOperationError.parentOperationCancelled)
                        return
                    }
                    continuation.resume(with: result)
                }
                operationQueue.addOperation(fetchOperation)
            }
            return try handle(json: json)
        } catch {
            handleFailure(with: error)
            throw error
        }
    }

    private func handle(json: JSON) throws -> [String: Data] {
        let versioningMap = try prepareVersionedJsons(from: json)
        handleCompletion(versioningMap: versioningMap)
        return versioningMap
    }

    private func prepareVersionedJsons(from json: JSON) throws -> [String: Data] {
        guard let versionedDefinitionJsons = json.arrayValue else {
            throw ChainsTypesSyncError.missingData
        }

        return try versionedDefinitionJsons.reduce([String: Data]()) { partialResult, json in
            var partialResult = partialResult

            guard let chainId = json.chainId?.stringValue else {
                throw ChainsTypesSyncError.missingChainId
            }

            let data = try JSONEncoder().encode(json)

            partialResult[chainId] = data
            return partialResult
        }
    }

    private func handleCompletion(versioningMap: [String: Data]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt = 0

        self.versioningMap = versioningMap
    }

    private func handleFailure(with _: Error) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt += 1

        if let delay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(delay)
        }
    }
}

// MARK: - SchedulerDelegate

extension ChainsTypesSyncService: SchedulerDelegate {
    public func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}

// MARK: - ChainsTypesSyncServiceProtocol

extension ChainsTypesSyncService: ChainsTypesSyncServiceProtocol {
    public func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }

    public func getTypes(for chainId: ChainModel.Id) async throws -> Data {
        if let types = mutex.withLock({ versioningMap[chainId] }) {
            return types
        }

        let remoteVersioningMap = try await fetchRemoteData()
        guard let types = remoteVersioningMap[chainId] else {
            throw ChainsTypesSyncError.missingData
        }
        return types
    }
}
