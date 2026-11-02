import Foundation
import RobinHood
import SSFUtils

protocol ScamSyncServiceProtocol {
    func syncUp()
}

enum ScamSyncError: Error {
    case emptyList
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
        guard let syncChanges = Self.syncChanges(remote: remote, local: local) else {
            complete(result: .failure(ScamSyncError.emptyList))
            return
        }

        handle(syncChanges: syncChanges)
    }

    /// An empty or unreadable download keeps the stored flags: deleting them would silence every warning.
    static func syncChanges(remote: [ScamInfo], local: [ScamInfo]) -> SyncChanges? {
        guard !remote.isEmpty else {
            return nil
        }

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

        return SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
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
        guard let stringValue = String(data: data, encoding: .utf8) else {
            return []
        }

        return Self.scamInfos(fromCsv: stringValue)
    }

    static func scamInfos(fromCsv csv: String) -> [ScamInfo] {
        var scamInfos: Set<ScamInfo> = []

        var rows = csv.components(separatedBy: .newlines)
        rows.removeFirst()

        rows.forEach { row in
            let columns = csvFields(of: row)

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

    /// A name such as `"Polkadot2022 Net, Polkadotevent2022"` is quoted because it holds a comma;
    /// splitting on every comma read the name's second half as the address.
    static func csvFields(of row: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var isQuoted = false
        var characters = row.makeIterator()

        while let character = characters.next() {
            switch character {
            case "\"" where isQuoted:
                // Two quotes inside a quoted field are one quote; one quote ends the quoting.
                let next = characters.next()
                if next == "\"" {
                    field.append("\"")
                    continue
                }
                isQuoted = false
                if next == "," {
                    fields.append(field)
                    field = ""
                } else if let next {
                    field.append(next)
                }
            case "\"" where field.isEmpty:
                isQuoted = true
            case "," where !isQuoted:
                fields.append(field)
                field = ""
            default:
                field.append(character)
            }
        }
        fields.append(field)

        return fields
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
