import Foundation
import RobinHood
import FearlessUtils

protocol PolkaswapSettingsSyncServiceProtocol {
    func syncUp()
}

final class PolkaswapSettingsSyncService {
    static let fetchLocalData = false

    private let settingsUrl: URL?
    private let repository: AnyDataProviderRepository<PolkaswapRemoteSettings>
    private let dataFetchFactory: DataOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        settingsUrl: URL?,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.settingsUrl = settingsUrl
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
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

        executeSync()
    }

    private func executeSync() {
        if Self.fetchLocalData {
            do {
                let localData = try fetchLocalData()
                decode(data: localData)
            } catch {
                complete(result: .failure(error))
            }
        } else {
            guard let settingsUrl = settingsUrl else {
                assertionFailure()
                return
            }
            fetchRemoteData(settingsUrl: settingsUrl)
        }
    }

    private func decode(data: Data) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let processingOperation: BaseOperation<(
            settings: PolkaswapRemoteSettings,
            localSettings: PolkaswapRemoteSettings?
        )> = ClosureOperation {
            let settings: PolkaswapRemoteSettings = try JSONDecoder().decode(PolkaswapRemoteSettings.self, from: data)
            let localChains = try localFetchOperation.extractNoCancellableResultData()

            return (
                settings: settings,
                localSettings: localChains.first
            )
        }

        processingOperation.completionBlock = { [weak self] in
            guard let result = processingOperation.result else {
                self?.complete(result: .failure(BaseOperationError.parentOperationCancelled))
                return
            }

            switch result {
            case let .success((remote, local)):
                self?.syncChanges(remote: remote, local: local)
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
        remote: PolkaswapRemoteSettings,
        local: PolkaswapRemoteSettings?
    ) {
        if remote.version != local?.version {
            handle(save: remote, remove: local)
        }
    }

    private func handle(save: PolkaswapRemoteSettings, remove: PolkaswapRemoteSettings?) {
        let localSaveOperation = repository.saveOperation({
            [save]
        }, {
            guard let remove = remove else {
                return []
            }
            return [remove.version]
        })

        DispatchQueue.global(qos: .userInitiated).async {
            self.complete(result: .success(save))
        }

        operationQueue.addOperation(localSaveOperation)
    }

    private func fetchRemoteData(settingsUrl: URL) {
        let remoteOperation = dataFetchFactory.fetchData(from: settingsUrl)

        remoteOperation.completionBlock = { [weak self] in
            guard let result = remoteOperation.result else {
                return
            }

            switch result {
            case let .success(settingsData):
                self?.decode(data: settingsData)
            case let .failure(error):
                self?.complete(result: .failure(error))
            }
        }

        operationQueue.addOperations(
            [remoteOperation],
            waitUntilFinished: false
        )
    }

    private func fetchLocalData() throws -> Data {
        guard let chainsUrl = Bundle.main.url(forResource: "polkaswapSettings", withExtension: "json")
        else {
            throw ChainSyncServiceError.missingLocalFile
        }

        return try Data(contentsOf: chainsUrl)
    }

    private func complete(result: Result<PolkaswapRemoteSettings, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        switch result {
        case let .success(settings):
            logger?.debug("Polkaswap sync completed: \(settings.version) (new or updated)")

            retryAttempt = 0
        case let .failure(error):
            logger?.error("Polkaswap sync failed with error: \(error)")

            retry()
        case .none:
            logger?.error("Polkaswap sync failed with no result")

            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling Polkaswap sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension PolkaswapSettingsSyncService: PolkaswapSettingsSyncServiceProtocol {
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

extension PolkaswapSettingsSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}
