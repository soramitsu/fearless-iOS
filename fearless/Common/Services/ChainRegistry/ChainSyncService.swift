import Foundation
import SoraFoundation
import RobinHood
import SSFUtils
import SSFNetwork
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
    static let blockscoutCompatibilityType = "subsquid"

    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    private let chainsUrl: URL
    private let dataFetchFactory: DataOperationFactoryProtocol
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
        chainsUrl: URL,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.chainsUrl = chainsUrl
        self.dataFetchFactory = dataFetchFactory
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

        DispatchQueue.main.async {
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
            let fetchOperation = dataFetchFactory.fetchData(from: chainsUrl)
            fetchOperation.completionBlock = { [weak self, weak fetchOperation] in
                guard
                    let self = self,
                    let operation = fetchOperation,
                    !operation.isCancelled
                else {
                    return
                }
                do {
                    let data = try operation.extractNoCancellableResultData()
                    let remoteChains = try self.decodeChainsTolerant(from: data)
                    self.handle(remoteChains: remoteChains)
                } catch {
                    self.complete(result: .failure(error))
                }
            }
            operationQueue.addOperation(fetchOperation)
        }
    }

    private func decodeChainsTolerant(from data: Data) throws -> [ChainModel] {
        do {
            return try JSONDecoder().decode([ChainModel].self, from: data)
        } catch {
            // Attempt a compatibility coercion for missing "tokens" field
            let coerced = try Self.coerceChainsPayloadForCompatibility(data)
            return try JSONDecoder().decode([ChainModel].self, from: coerced)
        }
    }

    static func coerceChainsPayloadForCompatibility(_ data: Data) throws -> Data {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard var array = obj as? [[String: Any]] else { return data }

        for i in 0 ..< array.count {
            if array[i]["tokens"] == nil {
                // Provide a minimal default remote tokens payload compatible with SSFModels
                array[i]["tokens"] = [
                    "type": "config",
                    "tokens": []
                ]
            }

            if array[i]["properties"] == nil {
                let prefixValue = array[i]["addressPrefix"]
                let prefixString: String

                if let intValue = prefixValue as? Int {
                    prefixString = String(intValue)
                } else if let stringValue = prefixValue as? String {
                    prefixString = stringValue
                } else if let number = prefixValue as? NSNumber {
                    prefixString = number.stringValue
                } else {
                    prefixString = "0"
                }

                array[i]["properties"] = ["addressPrefix": prefixString]
            }

            normalizeBlockExplorerTypes(in: &array[i])
        }

        return try JSONSerialization.data(withJSONObject: array, options: [])
    }

    private static func normalizeBlockExplorerTypes(in chainObject: inout [String: Any]) {
        guard var externalApi = chainObject["externalApi"] as? [String: Any] else {
            return
        }

        normalizeBlockExplorerType(in: &externalApi, key: "history")
        normalizeBlockExplorerType(in: &externalApi, key: "staking")

        if var explorers = externalApi["explorers"] as? [[String: Any]] {
            for index in explorers.indices {
                normalizeBlockExplorerType(in: &explorers[index], key: "type")
            }
            externalApi["explorers"] = explorers
        }

        chainObject["externalApi"] = externalApi
    }

    private static func normalizeBlockExplorerType(in object: inout [String: Any], key: String) {
        if var nested = object[key] as? [String: Any] {
            normalizeBlockExplorerType(in: &nested, key: "type")
            object[key] = nested
            return
        }

        guard
            let type = object[key] as? String,
            type.lowercased() == "blockscout"
        else {
            return
        }

        object[key] = blockscoutCompatibilityType
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
    func didStart(with _: TimeInterval) {
        isSyncing = true
    }

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with _: TimeInterval) {
        isSyncing = false
    }
}

extension ChainSyncService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        performSyncUpIfNeeded()
    }
}
