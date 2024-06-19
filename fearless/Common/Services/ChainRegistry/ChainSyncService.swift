import Foundation
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels
import SSFChainRegistry

protocol ChainSyncServiceProtocol {
    func syncUp()
}

enum ChainSyncServiceError: Error {
    case missingLocalFile
}

final class ChainSyncService {
    static let fetchLocalData = false

    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    private let syncService: SSFChainRegistry.ChainSyncServiceProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let eventCenter: EventCenterProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let applicationHandler: ApplicationHandlerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol?

    private var retryAttempt: Int = 0
    private var isSyncing: Bool = false
    private let mutex = NSLock()
    private var timer = CountdownTimer(notificationInterval: 300)

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        syncService: SSFChainRegistry.ChainSyncServiceProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.syncService = syncService
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.logger = logger
        self.applicationHandler = applicationHandler
        timer.delegate = self
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        DispatchQueue.main.sync {
            self.timer.start(with: 300)
        }
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync()
    }

    private func setApplicationDelegateIfNeeded() {
        guard applicationHandler.delegate == nil else {
            return
        }
        applicationHandler.delegate = self
    }

    private func executeSync() {
        if Self.fetchLocalData {
            do {
                let localData = try fetchLocalData()
                handle(remoteChains: localData)
            } catch {
                complete(result: .failure(error))
            }
        } else {
            Task {
                do {
                    let remoteChains = try await syncService.getChainModels()
                    handle(remoteChains: remoteChains)
                } catch {
                    complete(result: .failure(error))
                }
            }
        }
    }

    private func handle(remoteChains: [ChainModel]) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let processingOperation: BaseOperation<(
            remoteChains: [ChainModel],
            localChains: [ChainModel]
        )> = ClosureOperation {
            let localChains = try localFetchOperation.extractNoCancellableResultData()

            return (
                remoteChains: remoteChains,
                localChains: localChains
            )
        }

        processingOperation.completionBlock = { [weak self] in
            guard let result = processingOperation.result else {
                self?.complete(result: .failure(BaseOperationError.parentOperationCancelled))
                return
            }

            switch result {
            case let .success((remoteChains, localChains)):
                self?.syncChanges(
                    remoteChains: remoteChains,
                    localChains: localChains
                )
            case let .failure(error):
                self?.complete(result: .failure(error))
            }
        }

        processingOperation.addDependency(localFetchOperation)
        operationQueue.addOperations(
            [
                localFetchOperation,
                processingOperation
            ],
            waitUntilFinished: false
        )
    }

    private func syncChanges(
        remoteChains: [ChainModel],
        localChains: [ChainModel]
    ) {
        remoteChains.forEach { chain in
            chain.selectedNode = localChains.first(where: { $0.chainId == chain.chainId })?.selectedNode
        }

        let remoteMapping = remoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
            mapping[item.chainId] = item
        }

        let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
            mapping[item.chainId] = item
        }

        let newOrUpdated: [ChainModel] = remoteChains.compactMap { remoteItem in
            if let localItem = localMapping[remoteItem.chainId] {
                return localItem != remoteItem ? remoteItem : nil
            } else {
                return remoteItem
            }
        }

        let removed = localChains.compactMap { localItem in
            let isRemoved = remoteMapping[localItem.chainId] == nil
            return isRemoved ? localItem : nil
        }

        let syncChanges = SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
        handle(syncChanges: syncChanges)
    }

    private func handle(syncChanges: SyncChanges) {
        let localSaveOperation = repository.saveOperation({
            syncChanges.newOrUpdatedItems
        }, {
            syncChanges.removedItems.map { $0.identifier }
        })

        localSaveOperation.completionBlock = {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.complete(result: .success(syncChanges))
            }
        }

        operationQueue.addOperation(localSaveOperation)
    }

    private func fetchLocalData() throws -> [ChainModel] {
        guard let chainsUrl = Bundle.main.url(forResource: "chains", withExtension: "json") else {
            throw ChainSyncServiceError.missingLocalFile
        }

        let data = try Data(contentsOf: chainsUrl)
        return try JSONDecoder().decode([ChainModel].self, from: data)
    }

    private func complete(result: Result<SyncChanges, Error>) {
        switch result {
        case let .success(changes):
            if changes.newOrUpdatedItems.isNotEmpty {
                logger?.warning(
                    """
                    !!!! Make shure what chains.json was changed, if you see this message without chains.json changes, equatable ChainModel is broken !!!!
                    """
                )
                logger?.debug(
                    """
                    Sync completed: \(changes.newOrUpdatedItems.map { $0.name }) (new or updated)
                    """
                )
            }
            if changes.removedItems.isNotEmpty {
                logger?.debug(
                    """
                    Sync completed: \(changes.removedItems.map { $0.name }) (removed)
                    """
                )
            }

            retryAttempt = 0

            let event = ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            )

            eventCenter.notify(with: event)
        case let .failure(error):
            logger?.error("Sync failed with error: \(error)")
            timer.stop()
            let event = ChainSyncDidFail(error: error)
            eventCenter.notify(with: event)

            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        setApplicationDelegateIfNeeded()
        performSyncUpIfNeeded()
    }
}

extension ChainSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}

extension ChainSyncService: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        isSyncing = true
        print("CountdownTimerDelegate didStart", interval)
    }

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with remainedInterval: TimeInterval) {
        isSyncing = false
        print("CountdownTimerDelegate didStop", remainedInterval)
    }
}

extension ChainSyncService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        performSyncUpIfNeeded()
    }
}
