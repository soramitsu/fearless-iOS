import Foundation
import RobinHood
import SSFUtils

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

    let chainsUrl: URL?
    let assetsUrl: URL?
    let repository: AnyDataProviderRepository<ChainModel>
    let dataFetchFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        chainsUrl: URL?,
        assetsUrl: URL?,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.chainsUrl = chainsUrl
        self.assetsUrl = assetsUrl
        self.dataFetchFactory = dataFetchFactory
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
                decode(chainsData: localData.chainsData, assetsData: localData.assetsData)
            } catch {
                complete(result: .failure(error))
            }
        } else {
            guard let chainsUrl = chainsUrl, let assetsUrl = assetsUrl else {
                assertionFailure()
                return
            }
            fetchRemoteData(chainsUrl: chainsUrl, assetsUrl: assetsUrl)
        }
    }

    private func decode(chainsData: Data, assetsData: Data) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let processingOperation: BaseOperation<(
            remoteChains: [ChainModel],
            assetsList: [AssetModel],
            localChains: [ChainModel]
        )> = ClosureOperation {
            let remoteChains: [ChainModel] = try JSONDecoder().decode([ChainModel].self, from: chainsData)
            let assetsList: [AssetModel] = try JSONDecoder().decode([AssetModel].self, from: assetsData)
            let localChains = try localFetchOperation.extractNoCancellableResultData()

            return (
                remoteChains: remoteChains,
                assetsList: assetsList,
                localChains: localChains
            )
        }

        processingOperation.completionBlock = { [weak self] in
            guard let result = processingOperation.result else {
                self?.complete(result: .failure(BaseOperationError.parentOperationCancelled))
                return
            }

            switch result {
            case let .success((remoteChains, assetsList, localChains)):
                self?.syncChanges(
                    remoteChains: remoteChains,
                    assetsList: assetsList,
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
        assetsList: [AssetModel],
        localChains: [ChainModel]
    ) {
        remoteChains.forEach { chain in
            chain.assets.forEach { chainAsset in
                chainAsset.chain = chain
                if let asset = assetsList.first(where: { asset in
                    chainAsset.assetId == asset.id
                }) {
                    chainAsset.asset = asset
                }
            }
        }

        remoteChains.forEach { chain in
            chain.selectedNode = localChains.first(where: { $0.chainId == chain.chainId })?.selectedNode
        }

        remoteChains.forEach {
            $0.assets = $0.assets.filter { $0.asset != nil && $0.chain != nil }
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
            remoteMapping[localItem.chainId] == nil ? localItem : nil
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

    private func fetchRemoteData(
        chainsUrl: URL,
        assetsUrl: URL
    ) {
        let remoteFetchChainsOperation = dataFetchFactory.fetchData(from: chainsUrl)
        let remoteFetchAssetsOperation = dataFetchFactory.fetchData(from: assetsUrl)

        let mergeOperation: BaseOperation<(chainsData: Data, assetsData: Data)> = ClosureOperation {
            let remoteAssetsData = try remoteFetchAssetsOperation.extractNoCancellableResultData()
            let remoteChainsData = try remoteFetchChainsOperation.extractNoCancellableResultData()

            return (chainsData: remoteChainsData, assetsData: remoteAssetsData)
        }

        mergeOperation.completionBlock = { [weak self] in
            guard let result = mergeOperation.result else {
                return
            }

            switch result {
            case let .success((chainsData, assetsData)):
                self?.decode(chainsData: chainsData, assetsData: assetsData)
            case let .failure(error):
                self?.complete(result: .failure(error))
            }
        }

        mergeOperation.addDependency(remoteFetchChainsOperation)
        mergeOperation.addDependency(remoteFetchAssetsOperation)

        operationQueue.addOperations(
            [
                mergeOperation,
                remoteFetchChainsOperation,
                remoteFetchAssetsOperation
            ],
            waitUntilFinished: false
        )
    }

    private func fetchLocalData() throws -> (chainsData: Data, assetsData: Data) {
        guard
            let chainsUrl = Bundle.main.url(forResource: "chains", withExtension: "json"),
            let assetsUrl = Bundle.main.url(forResource: "assets", withExtension: "json")
        else {
            throw ChainSyncServiceError.missingLocalFile
        }

        let chainsData = try Data(contentsOf: chainsUrl)
        let assetsData = try Data(contentsOf: assetsUrl)

        return (chainsData: chainsData, assetsData: assetsData)
    }

    private func complete(result: Result<SyncChanges, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

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
