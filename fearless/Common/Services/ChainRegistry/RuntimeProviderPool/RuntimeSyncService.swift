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
    struct SyncInfo {
        let typesURL: URL?
        let connection: JSONRPCEngine
    }

    struct SyncResult {
        let chainId: ChainModel.Id
        let typesSyncResult: Result<String, Error>?
        let metadataSyncResult: Result<Void, Error>?
        let runtimeVersion: RuntimeVersion?
    }

    struct RetryAttempt {
        let chainId: ChainModel.Id
        let shouldSyncTypes: Bool
        let runtimeVersion: RuntimeVersion?
        let attempt: Int
    }

    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher
    let logger: LoggerProtocol?

    private(set) var knownChains: [ChainModel.Id: SyncInfo] = [:]
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
        maxConcurrentSyncRequests: Int = 8,
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
        shouldSyncTypes: Bool,
        newVersion: RuntimeVersion? = nil
    ) {
        guard let syncInfo = knownChains[chainId] else {
            return
        }

        let chainTypesSyncWrapper = shouldSyncTypes ? syncInfo.typesURL.map {
            createChainTypesSyncOperation(chainId, hasher: dataHasher, url: $0)
        } : nil

        let metadataSyncWrapper = newVersion.map {
            createMetadataSyncOperation(
                for: chainId,
                runtimeVersion: $0,
                connection: syncInfo.connection
            )
        }

        if chainTypesSyncWrapper == nil, metadataSyncWrapper == nil {
            return
        }

        let dependencies = (chainTypesSyncWrapper?.allOperations ?? []) +
            (metadataSyncWrapper?.allOperations ?? [])

        let processingOperation = ClosureOperation<SyncResult> {
            SyncResult(
                chainId: chainId,
                typesSyncResult: chainTypesSyncWrapper?.targetOperation.result,
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
                        typesSyncResult: .failure(error),
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
        let shouldSyncTypes: Bool

        if case .failure = result.typesSyncResult {
            shouldSyncTypes = true
        } else {
            shouldSyncTypes = false
        }

        let runtimeSyncVersion: RuntimeVersion?

        if let version = result.runtimeVersion, case .failure = result.metadataSyncResult {
            runtimeSyncVersion = version
        } else {
            runtimeSyncVersion = nil
        }

        if shouldSyncTypes || (runtimeSyncVersion != nil) {
            let nextAttempt = retryAttempts[result.chainId].map { $0.attempt + 1 } ?? 1

            let retryAttempt = RetryAttempt(
                chainId: result.chainId,
                shouldSyncTypes: shouldSyncTypes,
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
        logger?.debug("Did complete sync \(result)")

        if case let .success(fileHash) = result.typesSyncResult {
            logger?.debug("Did sync chain type: \(result.chainId)")

            let event = RuntimeChainTypesSyncCompleted(chainId: result.chainId, fileHash: fileHash)
            eventCenter.notify(with: event)
        }

        if case .success = result.metadataSyncResult, let version = result.runtimeVersion {
            logger?.debug("Did sync metadata: \(result.chainId)")

            let event = RuntimeMetadataSyncCompleted(chainId: result.chainId, version: version)
            eventCenter.notify(with: event)
        }
    }

    private func createChainTypesSyncOperation(
        _ chainId: ChainModel.Id,
        hasher: StorageHasher,
        url: URL
    ) -> CompoundOperationWrapper<String> {
        let remoteFileOperation = dataOperationFactory.fetchData(from: url)

        let fileSaveWrapper = filesOperationFactory.saveChainTypesOperation(for: chainId) {
            try remoteFileOperation.extractNoCancellableResultData()
        }

        fileSaveWrapper.addDependency(operations: [remoteFileOperation])

        let mapOperation = ClosureOperation<String> {
            _ = try fileSaveWrapper.targetOperation.extractNoCancellableResultData()
            let data = try remoteFileOperation.extractNoCancellableResultData()

            return try hasher.hash(data: data).toHex()
        }

        mapOperation.addDependency(fileSaveWrapper.targetOperation)
        mapOperation.addDependency(remoteFileOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [remoteFileOperation] + fileSaveWrapper.allOperations
        )
    }

    private func createMetadataSyncOperation(
        for chainId: ChainModel.Id,
        runtimeVersion: RuntimeVersion,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Void> {
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

        let saveMetadataOperation = repository.saveOperation({
            let hexMetadata = try remoteMetadaOperation.extractNoCancellableResultData()
            let rawMetadata = try Data(hexString: hexMetadata)
            let metadataItem = RuntimeMetadataItem(
                chain: chainId,
                version: runtimeVersion.specVersion,
                txVersion: runtimeVersion.transactionVersion,
                metadata: rawMetadata
            )

            return [metadataItem]
        }, { [] })

        saveMetadataOperation.addDependency(remoteMetadaOperation)

        let filterOperation = ClosureOperation<Void> {
            do {
                _ = try saveMetadataOperation.extractNoCancellableResultData()
            } catch let error as RuntimeSyncServiceError where error == .skipMetadataUnchanged {
                return
            }
        }

        filterOperation.addDependency(saveMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: [localMetadataOperation, remoteMetadaOperation, saveMetadataOperation]
        )
    }

    func clearOperations(for chainId: ChainModel.Id) {
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
                shouldSyncTypes: requestKeyValue.value.shouldSyncTypes,
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

        guard let syncInfo = knownChains[chain.chainId] else {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types?.url, connection: connection)
            return
        }

        if syncInfo.typesURL != chain.types?.url {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types?.url, connection: connection)

            performSync(for: chain.chainId, shouldSyncTypes: true)
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

        performSync(for: chainId, shouldSyncTypes: true, newVersion: version)
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
