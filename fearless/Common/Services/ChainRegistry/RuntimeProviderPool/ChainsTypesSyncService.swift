import Foundation
import FearlessUtils
import RobinHood

enum ChainsTypesSyncError: Error {
    case missingChainId
    case missingData
}

protocol ChainsTypesSyncServiceProtocol {
    func syncUp()
}

final class ChainsTypesSyncService {
    private let url: URL?
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let dataOperationFactory: DataOperationFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private var isSyncing: Bool = false
    private var retryAttempt: Int = 0

    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        url: URL?,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol
    ) {
        self.url = url
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            return
        }

        guard let url = url else {
            assertionFailure()
            return
        }

        isSyncing = true

        let fetchOperation = dataOperationFactory.fetchData(from: url)
        fetchOperation.completionBlock = { [weak self] in
            guard let result = fetchOperation.result else {
                self?.handleFailure(with: ChainsTypesSyncError.missingData)
                return
            }

            switch result {
            case let .success(data):
                self?.handle(data: data)
            case let .failure(error):
                self?.handleFailure(with: error)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handle(data: Data) {
        do {
            let versioningMap = try prepareVersionedJsons(from: data)
            handleCompletion(
                versioningMap: versioningMap
            )

            let saveOperation = filesOperationFactory.saveChainsTypesOperation {
                let jsonData = try JSONEncoder().encode(versioningMap.self)
                return jsonData
            }

            operationQueue.addOperations(saveOperation.allOperations, waitUntilFinished: false)
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    private func prepareVersionedJsons(from data: Data) throws -> [String: Data] {
        guard let versionedDefinitionJsons = try JSONDecoder().decode(JSON.self, from: data).arrayValue else {
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

        let event = RuntimeChainsTypesSyncCompleted(
            versioningMap: versioningMap
        )
        eventCenter.notify(with: event)
    }

    private func handleFailure(with error: Error) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt += 1

        logger.error(error.localizedDescription)

        if let delay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(delay)
        }
    }
}

// MARK: - SchedulerDelegate

extension ChainsTypesSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}

// MARK: - ChainsTypesSyncServiceProtocol

extension ChainsTypesSyncService: ChainsTypesSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }
}
