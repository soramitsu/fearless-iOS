import Foundation
import RobinHood
import FearlessUtils

enum RuntimeRegistryServiceError: Error {
    case missingBaseTypes
    case missingNetworkTypes
    case brokenMetadata
    case noNeedToUpdateTypes
    case unexpectedCoderFetchingFailure
    case timedOut
}

final class RuntimeRegistryService {
    static let queueLabelPrefix = "jp.co.fearless.runtime"

    private struct Snapshot {
        let localBaseHash: Data
        let localNetworkHash: Data
        let typeRegistryCatalog: TypeRegistryCatalogProtocol
        let specVersion: UInt32
        let txVersion: UInt32
        let metadata: RuntimeMetadata
    }

    private struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol) -> Void
        let metadata: RuntimeMetadata?
        let queue: DispatchQueue?
    }

    private(set) var chain: Chain
    private(set) var isActive: Bool = false

    let metadataProviderFactory: SubstrateDataProviderFactoryProtocol
    private(set) var metadataProvider: StreamableProvider<RuntimeMetadataItem>
    let dataOperationFactory: DataOperationFactoryProtocol
    let filesOperationFacade: RuntimeFilesOperationFacadeProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol?

    private var runtimeMetadata: RuntimeMetadataItem?
    private var snapshot: Snapshot?
    private var syncQueue = DispatchQueue(label: "\(queueLabelPrefix).\(UUID().uuidString)",
                                          qos: .userInitiated)
    private var pendingRequests: [PendingRequest] = []
    private var dataHasher: StorageHasher = .twox256
    private var snapshotLoadingWrapper: CompoundOperationWrapper<Snapshot>?
    private var syncTypesWrapper: CompoundOperationWrapper<Bool>?

    init(chain: Chain,
         metadataProviderFactory: SubstrateDataProviderFactoryProtocol,
         dataOperationFactory: DataOperationFactoryProtocol,
         filesOperationFacade: RuntimeFilesOperationFacadeProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol? = nil) {
        self.chain = chain
        self.metadataProviderFactory = metadataProviderFactory
        self.metadataProvider = metadataProviderFactory.createRuntimeMetadataItemProvider(for: chain)
        self.dataOperationFactory = dataOperationFactory
        self.filesOperationFacade = filesOperationFacade
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    private func fetchCoderFactory(for metadata: RuntimeMetadata?,
                                   runCompletionIn queue: DispatchQueue?,
                                   executing closure: @escaping (RuntimeCoderFactoryProtocol) -> Void) {
        let request = PendingRequest(resultClosure: closure, metadata: metadata, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func notifyPendingClosures(with snapshot: Snapshot) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: snapshot, to: $0) }

        logger?.debug("Fulfilled pendings")
    }

    private func deliver(snapshot: Snapshot, to request: PendingRequest) {
        let factory = RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog,
                                          specVersion: snapshot.specVersion,
                                          txVersion: snapshot.txVersion,
                                          metadata: snapshot.metadata)

        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(factory)
        }
    }

    private func subscribeMetadata() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<RuntimeMetadataItem>]) in
            self?.logger?.debug("Did receive changes \(changes.count)")
            for change in changes {
                if let item = change.item {
                    self?.runtimeMetadata = item
                    self?.updateTypeRegistryCatalog(shouldSyncFiles: true)
                    self?.logger?.debug("Did receive runtime metadata at version: \(item.version)")
                } else {
                    self?.runtimeMetadata = nil
                    self?.logger?.warning("Did delete runtime metadata")
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.logger?.error("Did receive runtime storage error: \(error)")
            return
        }

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 1,
                                                        refreshWhenEmpty: true)
        metadataProvider.addObserver(self,
                                     deliverOn: syncQueue,
                                     executing: updateClosure,
                                     failing: failureClosure,
                                     options: options)

        logger?.debug("Did subscribe to metadata")
    }

    private func unsubscribeMetadata() {
        metadataProvider.removeObserver(self)

        logger?.debug("Did unsubscribe from metadata")
    }

    private func loadTypeRegistryCatalog(hasher: StorageHasher, shouldSyncFiles: Bool) {
        guard let runtimeMetadata = runtimeMetadata else {
            return
        }

        cancelSnapshotLoadingIfNeeded()

        let baseTypesOperation = filesOperationFacade.fetchDefaultOperation(for: chain)
        let networkTypesOperation = filesOperationFacade.fetchNetworkOperation(for: chain)

        let decoderOperation: ScaleDecoderOperation<RuntimeMetadata> = ScaleDecoderOperation()
        decoderOperation.data = runtimeMetadata.metadata

        let combiningOperation = ClosureOperation<Snapshot> {
            guard
                let baseData = try baseTypesOperation.targetOperation
                    .extractNoCancellableResultData() else {
                throw RuntimeRegistryServiceError.missingBaseTypes
            }

            guard
                let networkData = try networkTypesOperation.targetOperation
                    .extractNoCancellableResultData() else {
                throw RuntimeRegistryServiceError.missingNetworkTypes
            }

            guard let metadata = try decoderOperation.extractNoCancellableResultData() else {
                throw RuntimeRegistryServiceError.brokenMetadata
            }

            let catalog = try TypeRegistryCatalog
                .createFromBaseTypeDefinition(baseData,
                                              networkDefinitionData: networkData,
                                              runtimeMetadata: metadata)

            let localBaseHash = try hasher.hash(data: baseData)
            let localNetworkHash = try hasher.hash(data: networkData)

            return Snapshot(localBaseHash: localBaseHash,
                            localNetworkHash: localNetworkHash,
                            typeRegistryCatalog: catalog,
                            specVersion: runtimeMetadata.version,
                            txVersion: runtimeMetadata.txVersion,
                            metadata: metadata)
        }

        let dependencies = baseTypesOperation.allOperations + networkTypesOperation.allOperations + [decoderOperation]

        dependencies.forEach { combiningOperation.addDependency($0) }

        snapshotLoadingWrapper = CompoundOperationWrapper(targetOperation: combiningOperation,
                                                          dependencies: dependencies)

        combiningOperation.completionBlock = {
            self.syncQueue.async {
                self.handleSnapshotLoadingCompletion(result: combiningOperation.result,
                                                     shouldSyncFiles: shouldSyncFiles)
            }
        }

        operationManager.enqueue(operations: dependencies + [combiningOperation], in: .transient)

        logger?.debug("Did start loading snapshot")
    }

    private func updateTypeRegistryCatalog(shouldSyncFiles: Bool) {
        snapshot = nil
        loadTypeRegistryCatalog(hasher: dataHasher, shouldSyncFiles: shouldSyncFiles)
    }

    private func handleSnapshotLoadingCompletion(result: Result<Snapshot, Error>?,
                                                 shouldSyncFiles: Bool) {
        guard let result = result else {
            return
        }

        snapshotLoadingWrapper = nil

        switch result {
        case .success(let snapshot):
            logger?.debug("Did complete loading snapshot version: \(snapshot.specVersion)")
            self.snapshot = snapshot

            notifyPendingClosures(with: snapshot)

            if shouldSyncFiles {
                syncTypeFiles()
            }

            DispatchQueue.main.async {
                let event = TypeRegistryPrepared(version: snapshot.specVersion)
                self.eventCenter.notify(with: event)
            }

        case .failure(let error):
            logger?.error("Loading runtime snapshot failed: \(error)")
        }
    }

    private func cancelSnapshotLoadingIfNeeded() {
        if snapshotLoadingWrapper != nil {
            snapshotLoadingWrapper?.allOperations.forEach { $0.cancel() }
            snapshotLoadingWrapper = nil
            logger?.debug("Snapshot loading cancelled")
        }
    }

    private func clear() {
        cancelSnapshotLoadingIfNeeded()
        cancelSyncTypesIfNeeded()
        snapshot = nil
        runtimeMetadata = nil
    }
}

extension RuntimeRegistryService {
    private func syncTypeFiles() {
        guard
            let snapshot = snapshot,
            let baseRemoteUrl = chain.typeDefDefaultFileURL(),
            let networkRemoteUrl = chain.typeDefNetworkFileURL() else {
            return
        }

        cancelSyncTypesIfNeeded()

        logger?.debug("Starting update runtime types")

        let baseTypeData = dataOperationFactory.fetchData(from: baseRemoteUrl)
        let networkTypeData = dataOperationFactory.fetchData(from: networkRemoteUrl)

        let baseSave = createBaseSaveOperation(for: snapshot,
                                               dependingOn: baseTypeData,
                                               networkRemote: networkTypeData,
                                               hasher: dataHasher)

        let networkSave = createNetworkSaveOperation(for: snapshot,
                                                     dependingOn: baseTypeData,
                                                     networkRemote: networkTypeData,
                                                     hasher: dataHasher)

        let syncOperation = createSyncOperation(dependingOn: baseSave, networkSave: networkSave)

        let saveOperations = baseSave.allOperations + networkSave.allOperations

        saveOperations.forEach {
            $0.addDependency(baseTypeData)
            $0.addDependency(networkTypeData)
        }

        saveOperations.forEach { syncOperation.addDependency($0) }

        syncOperation.completionBlock = {
            self.syncQueue.async {
                self.handleSync(result: syncOperation.result)
            }
        }

        let dependencies = [baseTypeData, networkTypeData] + saveOperations

        let wrapper = CompoundOperationWrapper(targetOperation: syncOperation,
                                               dependencies: dependencies)

        syncTypesWrapper = wrapper

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    private func handleSync(result: Result<Bool, Error>?) {
        guard let result = result else {
            return
        }

        syncTypesWrapper = nil

        if case .success(let shouldUpdate) = result, shouldUpdate {
            logger?.debug("Did change runtime types. Updating catalog...")
            self.updateTypeRegistryCatalog(shouldSyncFiles: false)
        } else {
            logger?.debug("No changes in runtime types")
        }
    }

    private func createBaseSaveOperation(for snapshot: Snapshot,
                                         dependingOn baseRemote: BaseOperation<Data>,
                                         networkRemote: BaseOperation<Data>,
                                         hasher: StorageHasher)
    -> CompoundOperationWrapper<Void> {
        filesOperationFacade.saveDefaultOperation(for: chain) {
            let data = try baseRemote.extractNoCancellableResultData()
            _ = try networkRemote.extractNoCancellableResultData()

            let remoteDataHash = try hasher.hash(data: data)

            guard remoteDataHash != snapshot.localBaseHash else {
                throw RuntimeRegistryServiceError.noNeedToUpdateTypes
            }

            return data
        }
    }

    private func createNetworkSaveOperation(for snapshot: Snapshot,
                                            dependingOn baseRemote: BaseOperation<Data>,
                                            networkRemote: BaseOperation<Data>,
                                            hasher: StorageHasher)
    -> CompoundOperationWrapper<Void> {
        filesOperationFacade.saveNetworkOperation(for: chain) {
            _ = try baseRemote.extractNoCancellableResultData()
            let data = try networkRemote.extractNoCancellableResultData()

            let remoteDataHash = try hasher.hash(data: data)

            guard remoteDataHash != snapshot.localNetworkHash else {
                throw RuntimeRegistryServiceError.noNeedToUpdateTypes
            }

            return data
        }
    }

    private func createSyncOperation(dependingOn baseSave: CompoundOperationWrapper<Void>,
                                     networkSave: CompoundOperationWrapper<Void>)
    -> ClosureOperation<Bool> {
        ClosureOperation<Bool> {
            let baseSaved: Bool
            if case .success = baseSave.targetOperation.result {
                baseSaved = true
            } else {
                baseSaved = false
            }

            let networkSaved: Bool
            if case .success = networkSave.targetOperation.result {
                networkSaved = true
            } else {
                networkSaved = false
            }

            return baseSaved || networkSaved
        }
    }

    private func cancelSyncTypesIfNeeded() {
        if syncTypesWrapper != nil {
            syncTypesWrapper?.allOperations.forEach { $0.cancel() }
            syncTypesWrapper = nil
            logger?.debug("Types wrapper sync cancelled")
        }
    }
}

extension RuntimeRegistryService: RuntimeRegistryServiceProtocol {
    func update(to chain: Chain) {
        syncQueue.async {
            if chain != self.chain {
                self.chain = chain

                if self.isActive {
                    self.unsubscribeMetadata()
                }

                self.clear()

                self.metadataProvider = self.metadataProviderFactory
                    .createRuntimeMetadataItemProvider(for: chain)

                if self.isActive {
                    self.subscribeMetadata()
                }
            }
        }
    }

    func setup() {
        syncQueue.async {
            if !self.isActive {
                self.isActive = true
                self.subscribeMetadata()
            }
        }
    }

    func throttle() {
        syncQueue.async {
            if self.isActive {
                self.isActive = false
                self.unsubscribeMetadata()

                self.clear()
            }
        }
    }
}

extension RuntimeRegistryService: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?)
    -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation {
            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let runtimeMetadata: RuntimeMetadata?

            if let closure = closure {
                runtimeMetadata = try closure()
            } else {
                runtimeMetadata = nil
            }

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchCoderFactory(for: runtimeMetadata, runCompletionIn: nil) { [weak semaphore] factory in
                    fetchedFactory = factory
                    semaphore?.signal()
                }
            }

            let result = semaphore.wait(timeout: DispatchTime.now() + .milliseconds(timeout.milliseconds))

            switch result {
            case .success:
                guard let factory = fetchedFactory else {
                    throw RuntimeRegistryServiceError.unexpectedCoderFetchingFailure
                }

                return factory
            case .timedOut:
                throw RuntimeRegistryServiceError.timedOut
            }
        }
    }
}
