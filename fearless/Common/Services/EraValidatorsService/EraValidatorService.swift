import Foundation
import RobinHood
import FearlessUtils

private typealias IdentifiableExposure = (Data, ValidatorExposure)

enum EraValidatorServiceError: Error {
    case unsuppotedStoragePath(_ path: StorageCodingPath)
}

final class EraValidatorService {
    static let queueLabelPrefix = "jp.co.fearless.recvalidators"

    private let syncQueue = DispatchQueue(label: "\(queueLabelPrefix).\(UUID().uuidString)")

    private var activeEra: UInt32?
    private var snapshot: EraStakersInfo?
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let eraDataProvider: StreamableProvider<ChainStorageItem>
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let storageKeyFactory: StorageKeyFactoryProtocol
    let localKeyFactory: ChainStorageIdFactoryProtocol
    let logger: LoggerProtocol

    init(storageFacade: StorageFacadeProtocol,
         runtimeCodingService: RuntimeCodingServiceProtocol,
         eraDataProvider: StreamableProvider<ChainStorageItem>,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol,
         storageKeyFactory: StorageKeyFactoryProtocol,
         localKeyFactory: ChainStorageIdFactoryProtocol,
         logger: LoggerProtocol) {
        self.storageFacade = storageFacade
        self.runtimeCodingService = runtimeCodingService
        self.eraDataProvider = eraDataProvider
        self.engine = engine
        self.operationManager = operationManager
        self.storageKeyFactory = storageKeyFactory
        self.localKeyFactory = localKeyFactory
        self.logger = logger
    }

    private func updateValidators(activeEra: UInt32,
                                  exposures: [IdentifiableExposure],
                                  prefs: [StorageResponse<ValidatorPrefs>]) {
        guard activeEra == self.activeEra else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        let keyedPrefs = prefs.reduce(into: [Data: ValidatorPrefs]()) { (result, item) in
            result[item.key] = item.value
        }

        let validators: [EraValidatorInfo] = exposures.compactMap { item in
            guard let pref = keyedPrefs[item.0] else {
                return nil
            }

            return EraValidatorInfo(accountId: item.0,
                                    exposure: item.1,
                                    prefs: pref)
        }

        snapshot = EraStakersInfo(era: activeEra,
                                  validators: validators)
    }

    private func updatePrefsAndSave(activeEra: UInt32,
                                    exposures: [IdentifiableExposure],
                                    codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        guard !exposures.isEmpty else {
            logger.warning("Tried to fetch prefs but era missing")
            return
        }

        let params1: () throws -> [UInt32] = {
            Array(repeating: activeEra, count: exposures.count)
        }

        let params2: () throws -> [Data] = {
            exposures.map { $0.0 }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: storageKeyFactory)

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> =
            requestFactory.queryItems(engine: engine,
                                      keyParams1: params1,
                                      keyParams2: params2,
                                      factory: { codingFactory },
                                      storagePath: .validatorPrefs)

        queryWrapper.targetOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let prefs = try queryWrapper.targetOperation.extractNoCancellableResultData()
                    self?.updateValidators(activeEra: activeEra,
                                           exposures: exposures,
                                           prefs: prefs)
                } catch {
                    self?.logger.error("Prefs fetching failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: queryWrapper.allOperations, in: .transient)
    }

    private func updateFromRemote(activeEra: UInt32,
                                  prefixKey: Data,
                                  repository: AnyDataProviderRepository<ChainStorageItem>,
                                  codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        let currentLocalFactory = localKeyFactory

        let request = PagedKeysRequest(key: prefixKey.toHex(includePrefix: true))
        let remoteValidatorIdsOperation =
            JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                         method: RPCMethod.getStorageKeysPaged,
                                                         parameters: request)

        let keys: () throws -> [Data] = {
            let hexKeys = try remoteValidatorIdsOperation.extractNoCancellableResultData()
            return try hexKeys.map { try Data(hexString: $0) }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: storageKeyFactory)

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> =
            requestFactory.queryItems(engine: engine,
                                      keys: keys,
                                      factory: { codingFactory },
                                      storagePath: .erasStakers)

        let saveOperation = repository.saveOperation({
            let result = try queryWrapper.targetOperation.extractNoCancellableResultData()
            return result.compactMap { item in
                    if let data = item.data {
                        let localId = currentLocalFactory.createIdentifier(for: item.key)
                        return ChainStorageItem(identifier: localId, data: data)
                    } else {
                        return nil
                    }
                }
        }, { [] })

        saveOperation.addDependency(queryWrapper.targetOperation)

        let operations = queryWrapper.allOperations + [saveOperation]

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

                    self?.updatePrefsAndSave(activeEra: activeEra,
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

    private func updateIfNeeded(activeEra: UInt32,
                                prefixKey: Data,
                                codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra else {
            Logger.shared.warning("Validators fetched but era changed. Cancelled.")
            return
        }

        let localPrefixKey = localKeyFactory.createIdentifier(for: prefixKey)
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
                        self?.updateFromRemote(activeEra: activeEra,
                                               prefixKey: prefixKey,
                                               repository: AnyDataProviderRepository(repository),
                                               codingFactory: codingFactory)
                    } else {
                        self?.updatePrefsAndSave(activeEra: activeEra,
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

    private func preparePrefixKeyAndUpdateIfNeeded() {
        guard let activeEra = activeEra else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let erasStakersKeyOperation = MapKeyEncodingOperation(path: .erasStakers,
                                                              storageKeyFactory: storageKeyFactory,
                                                              keyParams: [activeEra])

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
                        self?.updateIfNeeded(activeEra: activeEra, prefixKey: prefixKey, codingFactory: factory)
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
    }

    private func handleEraDecodingResult(_ result: Result<UInt32, Error>?) {
        switch result {
        case .success(let era):
            self.activeEra = era
            preparePrefixKeyAndUpdateIfNeeded()
        case .failure(let error):
            logger.error("Did receive era decoding error: \(error)")
        case .none:
            logger.warning("Error decoding operation canceled")
        }
    }

    private func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        guard let eraItem = eraItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<UInt32>(path: .activeEra,
                                                                 data: eraItem.data)

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                self?.handleEraDecodingResult(decodingOperation.result)
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, decodingOperation],
                                 in: .transient)
    }

    private func subscribe() {
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
    }

    private func unsubscribe() {
        eraDataProvider.removeObserver(self)
    }
}
