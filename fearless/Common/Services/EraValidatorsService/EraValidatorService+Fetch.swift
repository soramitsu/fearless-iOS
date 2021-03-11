import Foundation
import RobinHood
import FearlessUtils

private typealias IdentifiableExposure = (Data, ValidatorExposure)

extension EraValidatorService {
    private func updateValidators(chain: Chain,
                                  activeEra: UInt32,
                                  exposures: [IdentifiableExposure],
                                  prefs: [StorageResponse<ValidatorPrefs>]) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        let keyedPrefs = prefs.reduce(into: [Data: ValidatorPrefs]()) { (result, item) in
            let accountId = item.key.getAccountIdFromKey()
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

        didReceiveSnapshot(snapshot)
    }

    private func createPrefsWrapper(chain: Chain,
                                    activeEra: UInt32,
                                    identifiersClosure: @escaping () throws -> [Data],
                                    codingFactory: RuntimeCoderFactoryProtocol)
    -> CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> {
        guard let engine = engine else {
            logger?.warning("Can't find connection")
            return CompoundOperationWrapper.createWithError(EraValidatorServiceError.missingEngine)
        }

        let keys: () throws -> [Data] = {
            try identifiersClosure()
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        return requestFactory.queryItems(engine: engine,
                                         keyParams: keys,
                                         factory: { codingFactory },
                                         storagePath: .validatorPrefs)
    }

    private func createExposureWrapper(chain: Chain,
                                       activeEra: UInt32,
                                       keysClosure: @escaping () throws -> [Data],
                                       codingFactory: RuntimeCoderFactoryProtocol)
    -> CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> {
        guard let engine = engine else {
            logger?.warning("Can't find connection")
            return CompoundOperationWrapper.createWithError(EraValidatorServiceError.missingEngine)
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        return requestFactory.queryItems(engine: engine,
                                         keys: keysClosure,
                                         factory: { codingFactory },
                                         storagePath: .erasStakers)
    }

    private func createRemoteValidatorsFetch(for prefixKey: Data) -> BaseOperation<[String]> {
        guard let engine = engine else {
            logger?.warning("Can't find connection")
            return BaseOperation.createWithError(EraValidatorServiceError.missingEngine)
        }

        let request = PagedKeysRequest(key: prefixKey.toHex(includePrefix: true))
        return JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                            method: RPCMethod.getStorageKeysPaged,
                                                            parameters: request)
    }

    private func createValidatorsSave(for chain: Chain,
                                      repository: AnyDataProviderRepository<ChainStorageItem>,
                                      exposures: BaseOperation<[StorageResponse<ValidatorExposure>]>)
    -> BaseOperation<Void> {
        repository.saveOperation({
            let localFactory = try ChainStorageIdFactory(chain: chain)
            let result = try exposures.extractNoCancellableResultData()
            return result.compactMap { item in
                    if let data = item.data {
                        let localId = localFactory.createIdentifier(for: item.key)
                        return ChainStorageItem(identifier: localId, data: data)
                    } else {
                        return nil
                    }
                }
        }, { [] })
    }

    private func handleRemoteUpdate(chain: Chain,
                                    activeEra: UInt32,
                                    codingFactory: RuntimeCoderFactoryProtocol,
                                    exposureResponse: [StorageResponse<ValidatorExposure>],
                                    prefsResponse: [StorageResponse<ValidatorPrefs>]) {
        let exposures: [IdentifiableExposure] = exposureResponse.compactMap { item in
            guard let value = item.value else {
                return nil
            }

            let accountId = item.key.getAccountIdFromKey()
            return (accountId, value)
        }

        updateValidators(chain: chain,
                         activeEra: activeEra,
                         exposures: exposures,
                         prefs: prefsResponse)
    }

    private func updateFromRemote(chain: Chain,
                                  activeEra: UInt32,
                                  prefixKey: Data,
                                  repository: AnyDataProviderRepository<ChainStorageItem>,
                                  codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            logger?.warning("Wanted to fetch exposures but parameters changed. Cancelled.")
            return
        }

        let remoteValidatorIdsOperation = createRemoteValidatorsFetch(for: prefixKey)

        let keysClosure: () throws -> [Data] = {
            let hexKeys = try remoteValidatorIdsOperation.extractNoCancellableResultData()
            return try hexKeys.map { try Data(hexString: $0) }
        }

        let exposureWrapper = createExposureWrapper(chain: chain,
                                                    activeEra: activeEra,
                                                    keysClosure: keysClosure,
                                                    codingFactory: codingFactory)

        exposureWrapper.allOperations.forEach { $0.addDependency(remoteValidatorIdsOperation) }

        let identifiersClosure: () throws -> [Data] = {
            let keys = try keysClosure()
            return keys.map { $0.getAccountIdFromKey() }
        }

        let prefsWrapper = createPrefsWrapper(chain: chain,
                                              activeEra: activeEra,
                                              identifiersClosure: identifiersClosure,
                                              codingFactory: codingFactory)

        prefsWrapper.allOperations.forEach { $0.addDependency(remoteValidatorIdsOperation) }

        let saveOperation = createValidatorsSave(for: chain,
                                                 repository: repository,
                                                 exposures: exposureWrapper.targetOperation)

        saveOperation.addDependency(exposureWrapper.targetOperation)
        saveOperation.addDependency(prefsWrapper.targetOperation)

        let operations = [remoteValidatorIdsOperation] + exposureWrapper.allOperations +
            prefsWrapper.allOperations + [saveOperation]

        saveOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try exposureWrapper.targetOperation.extractNoCancellableResultData()
                    let prefs = try prefsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.handleRemoteUpdate(chain: chain,
                                             activeEra: activeEra,
                                             codingFactory: codingFactory,
                                             exposureResponse: exposures,
                                             prefsResponse: prefs)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func decodeLocalValidators(_ encodedItems: [ChainStorageItem],
                                       codingFactory: RuntimeCoderFactoryProtocol)
    -> CompoundOperationWrapper<[IdentifiableExposure]> {
        let decodingOperation = StorageDecodingListOperation<ValidatorExposure>(path: .erasStakers)
        decodingOperation.codingFactory = codingFactory
        decodingOperation.dataList = encodedItems.map { $0.data }

        let mapOperation: BaseOperation<[IdentifiableExposure]> = ClosureOperation {
            let identifiers = try encodedItems.map { item in
                try Data(hexString: item.identifier).getAccountIdFromKey()
            }
            let validators = try decodingOperation.extractNoCancellableResultData()

            return Array(zip(identifiers, validators))
        }

        mapOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [decodingOperation])
    }

    private func updateFromLocal(validators: [ChainStorageItem],
                                 chain: Chain,
                                 activeEra: UInt32,
                                 codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            logger?.warning("Wanted to fetch exposures but parameters changed. Cancelled.")
            return
        }

        let localDecoder = decodeLocalValidators(validators, codingFactory: codingFactory)

        let identifiersClosure = { try validators.map { try Data(hexString: $0.identifier).getAccountIdFromKey() } }

        let prefs = createPrefsWrapper(chain: chain,
                                       activeEra: activeEra,
                                       identifiersClosure: identifiersClosure,
                                       codingFactory: codingFactory)

        let syncOperation = Operation()
        syncOperation.addDependency(prefs.targetOperation)
        syncOperation.addDependency(localDecoder.targetOperation)

        syncOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try localDecoder.targetOperation.extractNoCancellableResultData()
                    let prefs = try prefs.targetOperation.extractNoCancellableResultData()
                    self?.updateValidators(chain: chain,
                                           activeEra: activeEra,
                                           exposures: exposures,
                                           prefs: prefs)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        let operations = localDecoder.allOperations + prefs.allOperations + [syncOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func updateIfNeeded(chain: Chain,
                                activeEra: UInt32,
                                prefixKey: Data,
                                codingFactory: RuntimeCoderFactoryProtocol) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Update triggered but parameters changed. Cancelled.")
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

        let localValidatorsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        localValidatorsOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let validators = try localValidatorsOperation.extractNoCancellableResultData()

                    if validators.isEmpty {
                        self?.updateFromRemote(chain: chain,
                                               activeEra: activeEra,
                                               prefixKey: prefixKey,
                                               repository: AnyDataProviderRepository(repository),
                                               codingFactory: codingFactory)
                    } else {
                        self?.updateFromLocal(validators: validators,
                                              chain: chain,
                                              activeEra: activeEra,
                                              codingFactory: codingFactory)
                    }
                } catch {
                    self?.logger?.error("Local fetch failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: [localValidatorsOperation], in: .transient)
    }

    private func preparePrefixKeyAndUpdateIfNeeded(chain: Chain, activeEra: UInt32) {
        guard activeEra == self.activeEra, chain == self.chain else {
            Logger.shared.warning("Prefix key for formed but parameters changed. Cancelled.")
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
                        self?.logger?.warning("Can't find coding factory or eras key")
                    }
                case .failure(let error):
                    self?.logger?.error("Prefix key encoding error: \(error)")
                case .none:
                    self?.logger?.warning("Did cancel prefix key encoding")
                }
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, erasStakersKeyOperation],
                                 in: .transient)
    }

    private func handleEraDecodingResult(chain: Chain, result: Result<ActiveEraInfo, Error>?) {
        guard chain == self.chain else {
            Logger.shared.warning("Era decoding triggered but chain changed. Cancelled.")
            return
        }

        switch result {
        case .success(let era):
            didReceiveActiveEra(era.index)
            preparePrefixKeyAndUpdateIfNeeded(chain: chain, activeEra: era.index)
        case .failure(let error):
            logger?.error("Did receive era decoding error: \(error)")
        case .none:
            logger?.warning("Error decoding operation canceled")
        }
    }

    func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        guard let chain = chain else {
            logger?.warning("Missing chain to proccess era")
            return
        }

        guard let eraItem = eraItem else {
            return
        }

        logger?.warning("Did receive era")

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

}
