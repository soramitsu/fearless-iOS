import Foundation
import RobinHood
import FearlessUtils

protocol RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection)
    func apply(version: RuntimeVersion, for chainId: ChainModel.Id)
}

enum RuntimeSyncServiceError: Error {
    case skipMetadataUnchanged
}

final class RuntimeSyncService {
    struct SyncInfo {
        let typesURL: URL?
        let connection: JSONRPCEngine
    }

    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let dataOperationFactory: DataOperationFactoryProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher

    private(set) var knownChains: [ChainModel.Id: SyncInfo] = [:]
    private var mutex = NSLock()

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        maxConcurrentSyncRequests: Int = 8,
        dataHasher: StorageHasher = .twox256
    ) {
        self.repository = repository
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.dataHasher = dataHasher

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
            createMetadataSyncOperation(for: chainId, runtimeVersion: $0, connection: syncInfo.connection)
        }

        if chainTypesSyncWrapper == nil, metadataSyncWrapper == nil {
            // TODO: Handle nothing todo case
            return
        }

        let dependencies = (chainTypesSyncWrapper?.allOperations ?? []) +
            (metadataSyncWrapper?.allOperations ?? [])

        let processingOperation = ClosureOperation<Void> {}

        dependencies.forEach { processingOperation.addDependency($0) }

        processingOperation.completionBlock = { [weak self] in
            DispatchQueue.global().async {
                self?.processSyncResult(
                    for: chainTypesSyncWrapper?.targetOperation.result,
                    metadataSyncResult: metadataSyncWrapper?.targetOperation.result,
                    runtimeVersion: newVersion
                )
            }
        }

        operationQueue.addOperations(dependencies + [processingOperation], waitUntilFinished: false)
    }

    private func processSyncResult(
        for typesSyncResult: Result<String, Error>?,
        metadataSyncResult: Result<Void, Error>?,
        runtimeVersion: RuntimeVersion?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
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
}

extension RuntimeSyncService: RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let syncInfo = knownChains[chain.chainId] else {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types, connection: connection)
            return
        }

        if syncInfo.typesURL != chain.types {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types, connection: connection)

            performSync(for: chain.chainId, shouldSyncTypes: true)
        }
    }

    func apply(version: RuntimeVersion, for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSync(for: chainId, shouldSyncTypes: true, newVersion: version)
    }
}
