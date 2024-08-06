import Foundation
import RobinHood
import SSFUtils

protocol ScamSyncServiceProtocol {
    func syncUp()
}

final class ScamSyncService: ScamSyncServiceProtocol {
    struct SyncChanges {
        let newOrUpdatedItems: [ScamInfo]
        let removedItems: [ScamInfo]
    }

    // MARK: - Private properties

    private let scamListCsvURL: URL?
    private let repository: AnyDataProviderRepository<ScamInfo>
    private let dataFetchFactory: DataOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue
    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    private var retryAttempt: Int = 0
    private var isSyncing: Bool = false
    private let mutex = NSLock()

    // MARK: - Constructor

    init(
        scamListCsvURL: URL?,
        repository: AnyDataProviderRepository<ScamInfo>,
        dataFetchFactory: DataOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol,
        operationQueue: OperationQueue
    ) {
        self.scamListCsvURL = scamListCsvURL
        self.repository = repository
        self.dataFetchFactory = dataFetchFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
    }

    // MARK: - Public methods

    func syncUp() {
        guard let scamUrl = scamListCsvURL else {
            return
        }

        let localOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let remoteOperation = dataFetchFactory.fetchData(from: scamUrl)

        let mergeOperation: BaseOperation<(
            remote: [ScamInfo],
            local: [ScamInfo]
        )> = ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw BaseOperationError.unexpectedDependentResult
            }
            let local = try localOperation.extractNoCancellableResultData()
            let remote = try strongSelf.handleRemote(remoteOperation.extractNoCancellableResultData())

            return (remote: remote, local: local)
        }

        mergeOperation.completionBlock = { [weak self] in
            guard let result = mergeOperation.result else {
                return
            }

            switch result {
            case let .success((remote, local)):
                self?.sync(remote: remote, local: local)
            case let .failure(error):
                self?.complete(result: .failure(error))
            }
        }

        mergeOperation.addDependency(localOperation)
        mergeOperation.addDependency(remoteOperation)

        operationQueue.addOperations(
            [
                mergeOperation,
                localOperation,
                remoteOperation
            ],
            waitUntilFinished: false
        )
    }

    // MARK: - Private methods

    private func complete(result: Result<SyncChanges, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        switch result {
        case .success:
            retryAttempt = 0
        case .failure:
            retry()
        }
    }

    private func sync(remote: [ScamInfo], local: [ScamInfo]) {
        let remoteMapping = remote.reduce(into: [String: ScamInfo]()) { mapping, item in
            mapping[item.address] = item
        }

        let localMapping = local.reduce(into: [String: ScamInfo]()) { mapping, item in
            mapping[item.address] = item
        }

        let newOrUpdated: [ScamInfo] = remote.compactMap { remoteItem in
            if let localItem = localMapping[remoteItem.address] {
                return (localItem != remoteItem) ? remoteItem : nil
            } else {
                return remoteItem
            }
        }

        let removed = local.compactMap { localItem in
            remoteMapping[localItem.address] == nil ? localItem : nil
        }

        let syncChanges = SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
        handle(syncChanges: syncChanges)
    }

    private func handle(syncChanges: SyncChanges) {
        let localSaveOperation = repository.saveBatchOperation {
            syncChanges.newOrUpdatedItems
        } _: {
            syncChanges.removedItems.map { $0.identifier }
        }

        DispatchQueue.global(qos: .background).async {
            self.complete(result: .success(syncChanges))
        }

        operationQueue.addOperation(localSaveOperation)
    }

    private func handleRemote(_ data: Data) -> [ScamInfo] {
        var scamInfos: Set<ScamInfo> = []

        guard let stringValue = String(data: data, encoding: .utf8) else {
            return []
        }
        var rows = stringValue.components(separatedBy: "\n")
        rows.removeFirst()

        rows.forEach { row in
            let columns = row.components(separatedBy: ",")

            guard
                let name = columns[safe: 0],
                let address = columns[safe: 1],
                let type = columns[safe: 2],
                let subtype = columns[safe: 3]
            else {
                return
            }

            let scamInfo = ScamInfo(
                name: name,
                address: address,
                type: ScamInfo.ScamType(from: type) ?? .unknown,
                subtype: subtype
            )

            scamInfos.insert(scamInfo)
        }

        return Array(scamInfos)
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(nextDelay)
        }
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            return
        }

        isSyncing = true
        retryAttempt += 1

        syncUp()
    }
}

extension ScamSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}
