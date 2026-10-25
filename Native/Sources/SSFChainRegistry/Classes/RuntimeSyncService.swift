import Foundation
import RobinHood
import SSFChainConnection
import SSFModels
import SSFNetwork
import SSFUtils

public protocol RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: SubstrateConnection) async throws
        -> RuntimeMetadataItem
    func unregister(chainId: ChainModel.Id)
    func getRuntimeItem(chainId: ChainModel.Id) throws -> RuntimeMetadataItem
}

public enum RuntimeSyncServiceError: Error {
    case skipMetadataUnchanged
    case runtimeItemsNotLoaded
    case missingRuntimeItem
    case missingConnection
    case missingRuntimeVersionResult
}

public final class RuntimeSyncService {
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

    private let dataOperationFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private var mutex = NSLock()
    private var retryScheduler: Scheduler?

    private var knownChains: [ChainModel.Id: SubstrateConnection] = [:]
    private var syncingChains: [ChainModel.Id: CompoundOperationWrapper<SyncResult>] = [:]
    private var metadataItems: [ChainModel.Id: RuntimeMetadataItem] = [:]
    private var retryAttempts: [ChainModel.Id: RetryAttempt] = [:]
    private var errors: [ChainModel.Id: Error] = [:]

    public init(
        dataOperationFactory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection()
    ) {
        self.dataOperationFactory = dataOperationFactory
        self.retryStrategy = retryStrategy

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        self.operationQueue = operationQueue
    }

    private func performSync(
        for chainId: ChainModel.Id,
        runtimeVersion: RuntimeVersion
    ) async throws -> RuntimeMetadataItem {
        guard let connection = knownChains[chainId] else {
            throw RuntimeSyncServiceError.missingConnection
        }

        let metadataSyncWrapper = createMetadataSyncOperation(
            for: chainId,
            runtimeVersion: runtimeVersion,
            connection: connection
        )

        let dependencies = metadataSyncWrapper.allOperations

        let processingOperation = ClosureOperation<SyncResult> {
            SyncResult(
                chainId: chainId,
                metadataSyncResult: metadataSyncWrapper.targetOperation.result,
                runtimeVersion: runtimeVersion
            )
        }

        dependencies.forEach { processingOperation.addDependency($0) }

        let wrapper = CompoundOperationWrapper(
            targetOperation: processingOperation,
            dependencies: dependencies
        )

        syncingChains[chainId] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return try await withUnsafeThrowingContinuation { continuation in
            processingOperation.completionBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let result = processingOperation.result
                switch result {
                case let .success(syncResult):
                    strongSelf.processSyncResult(syncResult)
                    let metadataSyncResult = syncResult.metadataSyncResult
                    switch metadataSyncResult {
                    case let .success(item):
                        guard let item = item else {
                            return
                        }
                        continuation.resume(returning: item)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    case .none:
                        continuation.resume(throwing: RuntimeSyncServiceError.missingRuntimeItem)
                    }
                case let .failure(error):
                    let result = SyncResult(
                        chainId: chainId,
                        metadataSyncResult: .failure(error),
                        runtimeVersion: runtimeVersion
                    )

                    strongSelf.processSyncResult(result)
                    continuation.resume(throwing: error)
                case .none:
                    continuation.resume(throwing: RuntimeSyncServiceError.missingRuntimeItem)
                }
            }
        }
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
            .value.attempt else
        {
            return
        }

        if let delay = retryStrategy.reconnectAfter(attempt: maxAttempt) {
            retryScheduler = Scheduler(with: self)
            retryScheduler?.notifyAfter(delay)
        }
    }

    private func notifyCompletion(for result: SyncResult) {
        if case .success = result.metadataSyncResult,
           let metadata = try? result.metadataSyncResult?.get()
        {
            metadataItems[result.chainId] = metadata
        }
    }

    private func createMetadataSyncOperation(
        for chainId: ChainModel.Id,
        runtimeVersion: RuntimeVersion,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeMetadataItem?> {
        let remoteMetadaOperation = JSONRPCOperation<[String], String>(
            engine: connection,
            method: RPCMethod.getRuntimeMetadata
        )

        let buildRuntimeMetadataOperation = ClosureOperation<RuntimeMetadataItem> {
            let hexMetadata = try remoteMetadaOperation.extractNoCancellableResultData()
            let rawMetadata = try Data(hexStringSSF: hexMetadata)
            let metadataItem = RuntimeMetadataItem(
                chain: chainId,
                version: runtimeVersion.specVersion,
                txVersion: runtimeVersion.transactionVersion,
                metadata: rawMetadata
            )

            return metadataItem
        }

        let filterOperation = ClosureOperation<RuntimeMetadataItem?> {
            do {
                let metadataItem = try buildRuntimeMetadataOperation
                    .extractNoCancellableResultData()
                return metadataItem
            } catch let error as RuntimeSyncServiceError where error == .skipMetadataUnchanged {
                return nil
            }
        }

        buildRuntimeMetadataOperation.addDependency(remoteMetadaOperation)
        filterOperation.addDependency(buildRuntimeMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: [
                remoteMetadaOperation,
                buildRuntimeMetadataOperation,
            ]
        )
    }

    private func getRemoteRuntimeVersion(with connection: SubstrateConnection) async throws
        -> RuntimeVersion
    {
        let remoteRuntimeVersionOperation = JSONRPCOperation<[String], RuntimeVersion>(
            engine: connection,
            method: RPCMethod.getRuntimeVersion
        )

        let operationQueue = OperationQueue()
        operationQueue.addOperation(remoteRuntimeVersionOperation)

        return try await withUnsafeThrowingContinuation { continuation in
            remoteRuntimeVersionOperation.completionBlock = {
                let result = remoteRuntimeVersionOperation.result
                switch result {
                case let .success(version):
                    continuation.resume(returning: version)
                case let .failure(error):
                    continuation.resume(throwing: error)
                case .none:
                    continuation
                        .resume(throwing: RuntimeSyncServiceError.missingRuntimeVersionResult)
                }
            }
        }
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
    public func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        retryScheduler = nil

        for requestKeyValue in retryAttempts where syncingChains[requestKeyValue.key] == nil {
            if let runtimeVersion = requestKeyValue.value.runtimeVersion {
                Task {
                    try? await performSync(
                        for: requestKeyValue.key,
                        runtimeVersion: runtimeVersion
                    )
                }
            }
        }
    }
}

extension RuntimeSyncService: RuntimeSyncServiceProtocol {
    public func register(
        chain: ChainModel,
        with connection: SubstrateConnection
    ) async throws -> RuntimeMetadataItem {
        if let runtimeMetadataItem = metadataItems[chain.chainId] {
            return runtimeMetadataItem
        }

        knownChains[chain.chainId] = connection

        let runtimeVersion = try await getRemoteRuntimeVersion(with: connection)
        let runtimeMetadataItem = try await performSync(
            for: chain.chainId,
            runtimeVersion: runtimeVersion
        )
        return runtimeMetadataItem
    }

    public func unregister(chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearOperations(for: chainId)
        knownChains[chainId] = nil
    }

    public func getRuntimeItem(chainId: ChainModel.Id) throws -> RuntimeMetadataItem {
        if let error = errors[chainId] {
            throw error
        }
        guard !metadataItems.isEmpty else {
            throw RuntimeSyncServiceError.runtimeItemsNotLoaded
        }
        guard let metadataItem = metadataItems[chainId] else {
            throw RuntimeSyncServiceError.missingRuntimeItem
        }
        return metadataItem
    }
}
