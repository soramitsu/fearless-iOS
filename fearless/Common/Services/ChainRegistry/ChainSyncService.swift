import Foundation
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
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol?

    private var retryAttempt: Int = 0
    private var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        syncService: SSFChainRegistry.ChainSyncServiceProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.syncService = syncService
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.logger = logger
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        isSyncing = true
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync()
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
            let isRemoved = remoteMapping[localItem.chainId] == nil || (remoteMapping[localItem.chainId]?.disabled == true)
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

        DispatchQueue.global(qos: .userInitiated).async {
            self.complete(result: .success(syncChanges))
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

    private func complete(result: Result<SyncChanges, Error>?) {
        isSyncing = false

        switch result {
        case let .success(changes):
            logger?.debug(
                """
                Sync completed: \(changes.newOrUpdatedItems) (new or updated),
                \(changes.removedItems) (removed)
                """
            )

            retryAttempt = 0

            let event = ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            )

            eventCenter.notify(with: event)
        case let .failure(error):
            logger?.error("Sync failed with error: \(error)")

            let event = ChainSyncDidFail(error: error)
            eventCenter.notify(with: event)

            retry()
        case .none:
            logger?.error("Sync failed with no result")

            let event = ChainSyncDidFail(error: BaseOperationError.unexpectedDependentResult)
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
