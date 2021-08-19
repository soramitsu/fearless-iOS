import Foundation
import FearlessUtils
import RobinHood

protocol CommonTypesSyncServiceProtocol {
    func syncUp()
}

class CommonTypesSyncService {
    let url: URL
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher

    private(set) var isSyncing: Bool = false
    private(set) var retryAttempt: Int = 0

    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        url: URL,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        dataHasher: StorageHasher = .twox256
    ) {
        self.url = url
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
    }

    private func performSyncUpIfNeeded(with dataHasher: StorageHasher) {
        guard !isSyncing else {
            return
        }

        isSyncing = true

        let fetchOperation = dataOperationFactory.fetchData(from: url)
        let saveOperation = filesOperationFactory.saveCommonTypesOperation {
            try fetchOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(operations: [fetchOperation])

        saveOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try saveOperation.targetOperation.extractNoCancellableResultData()
                    let data = try fetchOperation.extractNoCancellableResultData()

                    let remoteHash = try dataHasher.hash(data: data)

                    self?.handleCompletion(with: remoteHash)
                } catch {
                    self?.handleFailure(with: error)
                }
            }
        }

        operationQueue.addOperations(
            [fetchOperation] + saveOperation.allOperations,
            waitUntilFinished: false
        )
    }

    private func handleCompletion(with remoteHash: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt = 0

        let event = RuntimeCommonTypesSyncCompleted(fileHash: remoteHash.toHex())
        eventCenter.notify(with: event)
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

extension CommonTypesSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded(with: dataHasher)
    }
}

extension CommonTypesSyncService: CommonTypesSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded(with: dataHasher)
    }
}
