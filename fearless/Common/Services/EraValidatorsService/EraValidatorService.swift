import Foundation
import RobinHood
import FearlessUtils

private typealias IdentifiableExposure = (Data, ValidatorExposure)

enum EraValidatorServiceError: Error {
    case unsuppotedStoragePath(_ path: StorageCodingPath)
    case timedOut
    case unexpectedInfo
}

final class EraValidatorService {
    static let queueLabelPrefix = "jp.co.fearless.recvalidators"

    private struct PendingRequest {
        let resultClosure: (EraStakersInfo) -> Void
        let queue: DispatchQueue?
    }

    private let syncQueue = DispatchQueue(label: "\(queueLabelPrefix).\(UUID().uuidString)")

    private var activeEra: UInt32?
    private var chain: Chain?
    private var engine: JSONRPCEngine?
    private var isActive: Bool = false

    private var snapshot: EraStakersInfo?
    private var eraDataProvider: StreamableProvider<ChainStorageItem>?

    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    private var pendingRequests: [PendingRequest] = []
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(storageFacade: StorageFacadeProtocol,
         runtimeCodingService: RuntimeCodingServiceProtocol,
         providerFactory: SubstrateDataProviderFactoryProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.storageFacade = storageFacade
        self.runtimeCodingService = runtimeCodingService
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.logger = logger
    }

    private func fetchInfoFactory(runCompletionIn queue: DispatchQueue?,
                                  executing closure: @escaping (EraStakersInfo) -> Void) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func notifyPendingClosures(with info: EraStakersInfo) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: info, to: $0) }

        logger.debug("Fulfilled pendings")
    }

    private func deliver(snapshot: EraStakersInfo, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }

    private func updateValidators(chain: Chain,
                                  activeEra: UInt32,
                                  exposures: [IdentifiableExposure],
                                  prefs: [StorageResponse<ValidatorPrefs>]) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        let keyedPrefs = prefs.reduce(into: [Data: ValidatorPrefs]()) { (result, item) in
            let accountId = item.key.suffix(Int(ExtrinsicConstants.accountIdLength))
            result[accountId] = item.value
        }

        let validators: [EraValidatorInfo] = exposures.compactMap { item in
            guard let pref = keyedPrefs[item.0] else {
                return nil
            }

            return EraValidatorInfo(accountId: item.0,
                                    exposure: item.1,
                                    prefs: pref)
        }

        let snapshot = EraStakersInfo(era: activeEra,
                                      validators: validators)
        self.snapshot = snapshot

        notifyPendingClosures(with: snapshot)
    }

    private func updatePrefsAndSave(chain: Chain,
                                    activeEra: UInt32,
                                    exposures: [IdentifiableExposure],
                                    codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        guard !exposures.isEmpty else {
            logger.warning("Tried to fetch prefs but era missing")
            return
        }

        guard let engine = engine else {
            logger.warning("Can't find connection")
            return
        }

        let params1: () throws -> [String] = {
            Array(repeating: String(activeEra), count: exposures.count)
        }

        let params2: () throws -> [Data] = {
            exposures.map { $0.0 }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> =
            requestFactory.queryItems(engine: engine,
                                      keyParams1: params1,
                                      keyParams2: params2,
                                      factory: { codingFactory },
                                      storagePath: .erasPrefs)

        queryWrapper.targetOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let prefs = try queryWrapper.targetOperation.extractNoCancellableResultData()
                    self?.updateValidators(chain: chain,
                                           activeEra: activeEra,
                                           exposures: exposures,
                                           prefs: prefs)
                } catch {
                    self?.logger.error("Prefs fetching failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: queryWrapper.allOperations, in: .transient)
    }

    private func updateFromRemote(chain: Chain,
                                  activeEra: UInt32,
                                  prefixKey: Data,
                                  repository: AnyDataProviderRepository<ChainStorageItem>,
                                  codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        guard let engine = engine else {
            logger.warning("Can't find connection")
            return
        }

        let request = PagedKeysRequest(key: prefixKey.toHex(includePrefix: true))
        let remoteValidatorIdsOperation =
            JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                         method: RPCMethod.getStorageKeysPaged,
                                                         parameters: request)

        let keys: () throws -> [Data] = {
            let hexKeys = try remoteValidatorIdsOperation.extractNoCancellableResultData()
            return try hexKeys.map { try Data(hexString: $0) }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> =
            requestFactory.queryItems(engine: engine,
                                      keys: keys,
                                      factory: { codingFactory },
                                      storagePath: .erasStakers)

        queryWrapper.allOperations.forEach { $0.addDependency(remoteValidatorIdsOperation) }

        let saveOperation = repository.saveOperation({
            let localFactory = try ChainStorageIdFactory(chain: chain)
            let result = try queryWrapper.targetOperation.extractNoCancellableResultData()
            return result.compactMap { item in
                    if let data = item.data {
                        let localId = localFactory.createIdentifier(for: item.key)
                        return ChainStorageItem(identifier: localId, data: data)
                    } else {
                        return nil
                    }
                }
        }, { [] })

        saveOperation.addDependency(queryWrapper.targetOperation)

        let operations = [remoteValidatorIdsOperation] + queryWrapper.allOperations + [saveOperation]

        saveOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let result = try queryWrapper.targetOperation.extractNoCancellableResultData()
                    let exposures: [IdentifiableExposure] = result.compactMap { item in
                        guard let value = item.value else {
                            return nil
                        }

                        let accountId = item.key.suffix(Int(ExtrinsicConstants.accountIdLength))
                        return (accountId, value)
                    }

                    self?.updatePrefsAndSave(chain: chain,
                                             activeEra: activeEra,
                                             exposures: exposures,
                                             codingFactory: codingFactory)
                } catch {
                    self?.logger.error("Remote exposure failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func createLocalValidatorsWrapper(repository: AnyDataProviderRepository<ChainStorageItem>,
                                              codingFactory: RuntimeCoderFactoryProtocol)
    -> CompoundOperationWrapper<[IdentifiableExposure]> {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let decodingOperation = StorageDecodingListOperation<ValidatorExposure>(path: .erasStakers)
        decodingOperation.codingFactory = codingFactory

        decodingOperation.configurationBlock = {
            do {
                guard let validators = try fetchOperation.extractResultData() else {
                    decodingOperation.cancel()
                    return
                }

                decodingOperation.dataList = validators.map { $0.data }
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(fetchOperation)

        let mapOperation: BaseOperation<[IdentifiableExposure]> = ClosureOperation {
            let identifiers = try fetchOperation.extractNoCancellableResultData().map { item in
                try Data(hexString: item.identifier)
                    .suffix(Int(ExtrinsicConstants.accountIdLength))
            }
            let validators = try decodingOperation.extractNoCancellableResultData()

            return Array(zip(identifiers, validators))
        }

        mapOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: [fetchOperation, decodingOperation])
    }

    private func updateIfNeeded(chain: Chain,
                                activeEra: UInt32,
                                prefixKey: Data,
                                codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        guard let localFactory = try? ChainStorageIdFactory(chain: chain) else {
            Logger.shared.error("Can't create local factory")
            return
        }

        let localPrefixKey = localFactory.createIdentifier(for: prefixKey)

        let filter = NSPredicate.filterByIdPrefix(localPrefixKey)

        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository(filter: filter)
        let anyRepository = AnyDataProviderRepository(repository)

        let localValidatorsWrapper =
            createLocalValidatorsWrapper(repository: anyRepository,
                                         codingFactory: codingFactory)

        localValidatorsWrapper.targetOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let validators = try localValidatorsWrapper.targetOperation
                        .extractNoCancellableResultData()

                    if validators.isEmpty {
                        self?.updateFromRemote(chain: chain,
                                               activeEra: activeEra,
                                               prefixKey: prefixKey,
                                               repository: AnyDataProviderRepository(repository),
                                               codingFactory: codingFactory)
                    } else {
                        self?.updatePrefsAndSave(chain: chain,
                                                 activeEra: activeEra,
                                                 exposures: validators,
                                                 codingFactory: codingFactory)
                    }
                } catch {
                    self?.logger.error("Local fetch failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: localValidatorsWrapper.allOperations,
                                 in: .transient)
    }

    private func preparePrefixKeyAndUpdateIfNeeded(chain: Chain, activeEra: UInt32) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let erasStakersKeyOperation = MapKeyEncodingOperation(path: .erasStakers,
                                                              storageKeyFactory: StorageKeyFactory(),
                                                              keyParams: [String(activeEra)])

        erasStakersKeyOperation.configurationBlock = {
            do {
                erasStakersKeyOperation.codingFactory =
                    try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                erasStakersKeyOperation.result = .failure(error)
            }
        }

        erasStakersKeyOperation.addDependency(codingFactoryOperation)

        erasStakersKeyOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                switch erasStakersKeyOperation.result {
                case .success(let prefixKeys):
                    if let factory = erasStakersKeyOperation.codingFactory, let prefixKey = prefixKeys.first {
                        self?.updateIfNeeded(chain: chain,
                                             activeEra: activeEra,
                                             prefixKey: prefixKey,
                                             codingFactory: factory)
                    } else {
                        self?.logger.warning("Can't find coding factory or eras key")
                    }
                case .failure(let error):
                    self?.logger.error("Prefix key encoding error: \(error)")
                case .none:
                    self?.logger.warning("Did cancel prefix key encoding")
                }
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, erasStakersKeyOperation],
                                 in: .transient)
    }

    private func handleEraDecodingResult(chain: Chain, result: Result<ActiveEraInfo, Error>?) {
        guard chain == self.chain else {
            Logger.shared.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        switch result {
        case .success(let era):
            self.activeEra = era.index
            preparePrefixKeyAndUpdateIfNeeded(chain: chain, activeEra: era.index)
        case .failure(let error):
            logger.error("Did receive era decoding error: \(error)")
        case .none:
            logger.warning("Error decoding operation canceled")
        }
    }

    private func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        guard let chain = chain else {
            logger.warning("Missing chain to proccess era")
            return
        }

        guard let eraItem = eraItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<ActiveEraInfo>(path: .activeEra,
                                                                        data: eraItem.data)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                self?.handleEraDecodingResult(chain: chain, result: decodingOperation.result)
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, decodingOperation],
                                 in: .transient)
    }

    private func subscribe() {
        do {
            guard let chain = self.chain else {
                Logger.shared.warning("Missing chain to subscribe")
                return
            }

            let localFactory = try ChainStorageIdFactory(chain: chain)

            let path = StorageCodingPath.activeEra
            let key = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                               storageName: path.itemName)

            let localKey = localFactory.createIdentifier(for: key)
            let eraDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                    switch item {
                    case .insert(let newItem), .update(let newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateActiveEraItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] (error) in
                self?.logger.error("Did receive error: \(error)")
            }

            eraDataProvider.addObserver(self,
                                        deliverOn: syncQueue,
                                        executing: updateClosure,
                                        failing: failureClosure,
                                        options: StreamableProviderObserverOptions())

            self.eraDataProvider = eraDataProvider
        } catch {
            logger.error("Can't make subscription")
        }
    }

    private func unsubscribe() {
        eraDataProvider?.removeObserver(self)
        eraDataProvider = nil
    }
}

extension EraValidatorService: EraValidatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func update(to chain: Chain, engine: JSONRPCEngine) {
        syncQueue.async {
            if self.isActive {
                self.unsubscribe()
            }

            self.snapshot = nil
            self.activeEra = nil
            self.engine = engine
            self.chain = chain

            if self.isActive {
                self.subscribe()
            }
        }
    }

    func fetchInfoOperation(with timeout: TimeInterval) -> BaseOperation<EraStakersInfo> {
        ClosureOperation {
            var fetchedInfo: EraStakersInfo?

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            let result = semaphore.wait(timeout: DispatchTime.now() + .milliseconds(timeout.milliseconds))

            switch result {
            case .success:
                guard let info = fetchedInfo else {
                    throw EraValidatorServiceError.unexpectedInfo
                }

                return info
            case .timedOut:
                throw EraValidatorServiceError.timedOut
            }
        }
    }
}

