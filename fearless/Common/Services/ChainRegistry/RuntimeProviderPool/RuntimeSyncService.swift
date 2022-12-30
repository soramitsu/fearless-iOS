import Foundation
import RobinHood
import FearlessUtils

protocol RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection)
    func unregister(chainId: ChainModel.Id)
    func apply(version: RuntimeVersion, for chainId: ChainModel.Id)

    func hasChain(with chainId: ChainModel.Id) -> Bool
    func isChainSyncing(_ chainId: ChainModel.Id) -> Bool
}

enum RuntimeSyncServiceError: Error {
    case skipMetadataUnchanged
}

final class RuntimeSyncService {
    struct SyncResult {
        let chainId: ChainModel.Id
        let metadataSyncResult: Result<RuntimeMetadataItem?, Error>?
        let runtimeVersion: RuntimeVersion?
    }

    struct RetryAttempt {
        let chainId: ChainModel.Id
        let runtimeVersion: RuntimeVersion?
        let attempt: Int
    }

    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let dataOperationFactory: DataOperationFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue
    private let dataHasher: StorageHasher
    private let logger: LoggerProtocol?

    private(set) var knownChains: [ChainModel.Id: ChainConnection] = [:]
    private(set) var syncingChains: [ChainModel.Id: CompoundOperationWrapper<SyncResult>] = [:]
    private(set) var retryAttempts: [ChainModel.Id: RetryAttempt] = [:]
    private var mutex = NSLock()
    private var retryScheduler: Scheduler?

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        maxConcurrentSyncRequests: Int = 16,
        dataHasher: StorageHasher = .twox256,
        logger: LoggerProtocol? = nil
    ) {
        self.repository = repository
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.retryStrategy = retryStrategy
        self.eventCenter = eventCenter
        self.dataHasher = dataHasher
        self.logger = logger

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = maxConcurrentSyncRequests
        operationQueue.qualityOfService = .userInitiated
        self.operationQueue = operationQueue
    }

    private func performSync(
        for chainId: ChainModel.Id,
        newVersion: RuntimeVersion? = nil
    ) {
        guard let connection = knownChains[chainId] else {
            return
        }

        let metadataSyncWrapper = newVersion.map {
            createMetadataSyncOperation(
                for: chainId,
                runtimeVersion: $0,
                connection: connection
            )
        }

        if metadataSyncWrapper == nil {
            return
        }

        let dependencies = (metadataSyncWrapper?.allOperations ?? [])

        let processingOperation = ClosureOperation<SyncResult> {
            SyncResult(
                chainId: chainId,
                metadataSyncResult: metadataSyncWrapper?.targetOperation.result,
                runtimeVersion: newVersion
            )
        }

        dependencies.forEach { processingOperation.addDependency($0) }

        processingOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processingOperation.extractNoCancellableResultData()
                    self?.processSyncResult(result)
                } catch let error as BaseOperationError where error == .parentOperationCancelled {
                    return
                } catch {
                    let result = SyncResult(
                        chainId: chainId,
                        metadataSyncResult: .failure(error),
                        runtimeVersion: newVersion
                    )

                    self?.processSyncResult(result)
                }
            }
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: processingOperation,
            dependencies: dependencies
        )

        syncingChains[chainId] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func processSyncResult(_ result: SyncResult) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncingChains[result.chainId] = nil

        addRetryRequestIfNeeded(for: result)

        notifyCompletion(for: result)
    }

    private func addRetryRequestIfNeeded(for result: SyncResult) {
        let runtimeSyncVersion: RuntimeVersion?

        if let version = result.runtimeVersion, case .failure = result.metadataSyncResult {
            runtimeSyncVersion = version
        } else {
            runtimeSyncVersion = nil
        }

        if runtimeSyncVersion != nil {
            let nextAttempt = retryAttempts[result.chainId].map { $0.attempt + 1 } ?? 1

            let retryAttempt = RetryAttempt(
                chainId: result.chainId,
                runtimeVersion: runtimeSyncVersion,
                attempt: nextAttempt
            )

            retryAttempts[result.chainId] = retryAttempt

            rescheduleRetryIfNeeded()
        } else {
            retryAttempts[result.chainId] = nil
        }
    }

    private func rescheduleRetryIfNeeded() {
        guard retryScheduler == nil else {
            return
        }

        guard let maxAttempt = retryAttempts.max(by: { $0.value.attempt < $1.value.attempt })?
            .value.attempt else {
            return
        }

        if let delay = retryStrategy.reconnectAfter(attempt: maxAttempt) {
            retryScheduler = Scheduler(with: self)
            retryScheduler?.notifyAfter(delay)
        }
    }

    private func notifyCompletion(for result: SyncResult) {
        if
            case .success = result.metadataSyncResult,
            let version = result.runtimeVersion,
            let metadata = try? result.metadataSyncResult?.get() {
            logger?.debug("Did sync metadata: \(result.chainId)")

            let event = RuntimeMetadataSyncCompleted(
                chainId: result.chainId,
                version: version,
                metadata: metadata
            )
            eventCenter.notify(with: event)
        }
    }

    private func createMetadataSyncOperation(
        for chainId: ChainModel.Id,
        runtimeVersion: RuntimeVersion,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeMetadataItem?> {
        let localMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let remoteMetadaOperation = JSONRPCOperation<[String], String>(
            engine: connection,
            method: RPCMethod.getRuntimeMetadata
        )

        remoteMetadaOperation.configurationBlock = {
            do {
                let currentItem = try localMetadataOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                if let item = currentItem, item.version == runtimeVersion.specVersion {
                    remoteMetadaOperation.result = .failure(RuntimeSyncServiceError.skipMetadataUnchanged)
                }
            } catch {
                remoteMetadaOperation.result = .failure(error)
            }
        }

        remoteMetadaOperation.addDependency(localMetadataOperation)

        let buildRuntimeMetadataOperation = ClosureOperation<RuntimeMetadataItem> {
            let hexMetadata = try remoteMetadaOperation.extractNoCancellableResultData()
            let rawMetadata = try Data(hexString: hexMetadata)
            let metadataItem = RuntimeMetadataItem(
                chain: chainId,
                version: runtimeVersion.specVersion,
                txVersion: runtimeVersion.transactionVersion,
                metadata: rawMetadata
            )

            return metadataItem
        }

        let saveMetadataOperation = repository.saveOperation({
            let metadataItem = try buildRuntimeMetadataOperation.extractNoCancellableResultData()
            return [metadataItem]
        }, { [] })

        let filterOperation = ClosureOperation<RuntimeMetadataItem?> {
            do {
                let metadataItem = try buildRuntimeMetadataOperation.extractNoCancellableResultData()
                return metadataItem
            } catch let error as RuntimeSyncServiceError where error == .skipMetadataUnchanged {
                return nil
            }
        }

        buildRuntimeMetadataOperation.addDependency(remoteMetadaOperation)
        saveMetadataOperation.addDependency(buildRuntimeMetadataOperation)
        filterOperation.addDependency(buildRuntimeMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: [
                localMetadataOperation,
                remoteMetadaOperation,
                buildRuntimeMetadataOperation,
                saveMetadataOperation
            ]
        )
    }

    private func clearOperations(for chainId: ChainModel.Id) {
        if let existingOperation = syncingChains[chainId] {
            syncingChains[chainId] = nil
            existingOperation.cancel()
        }

        retryAttempts[chainId] = nil
    }
}

extension RuntimeSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        retryScheduler = nil

        for requestKeyValue in retryAttempts where syncingChains[requestKeyValue.key] == nil {
            performSync(
                for: requestKeyValue.key,
                newVersion: requestKeyValue.value.runtimeVersion
            )
        }
    }
}

extension RuntimeSyncService: RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let knownConnection = knownChains[chain.chainId] else {
            knownChains[chain.chainId] = connection
            return
        }

        if knownConnection.url != connection.url {
            knownChains[chain.chainId] = connection

            performSync(for: chain.chainId)
        }
    }

    func unregister(chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearOperations(for: chainId)
        knownChains[chainId] = nil
    }

    func apply(version: RuntimeVersion, for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearOperations(for: chainId)

        performSync(for: chainId, newVersion: version)
    }

    func hasChain(with chainId: ChainModel.Id) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return knownChains[chainId] != nil
    }

    func isChainSyncing(_ chainId: ChainModel.Id) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return (syncingChains[chainId] != nil) || (retryAttempts[chainId] != nil)
    }
}
