import Foundation
import SSFModels
import SSFUtils
import RobinHood

private typealias IdentifiableExposureMetadata = (Data, ValidatorExposureMetadata)

extension EraValidatorService {
//    private let syncQueue = DispatchQueue(
//        label: "jp.co.fearless.defvalidators.\(UUID().uuidString)",
//        qos: .userInitiated
//    )
//
//    private let chainRegistry: ChainRegistryProtocol
//    private let chainId: ChainModel.Id
//    private let operationManager: OperationManagerProtocol
//    private let logger: LoggerProtocol?
//    private let storageFacade: StorageFacadeProtocol
//    private let chain: ChainModel
//
//    init(
//        chainRegistry: ChainRegistryProtocol,
//        chainId: ChainModel.Id,
//        operationManager: OperationManagerProtocol,
//        logger: LoggerProtocol?,
//        storageFacade: StorageFacadeProtocol,
//        chain: ChainModel
//    ) {
//        self.chainRegistry = chainRegistry
//        self.chainId = chainId
//        self.operationManager = operationManager
//        self.logger = logger
//        self.storageFacade = storageFacade
//        self.chain = chain
//    }

    private func updateValidators(
        activeEra: UInt32,
        exposures: [Data: ValidatorExposureMetadata],
        prefs: [Data: ValidatorPrefs],
        others: [Data: ValidatorExposurePage],
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        let validators: [EraValidatorInfo] = exposures.compactMap { item in
            guard let pref = prefs[item.0], let others = others[item.0] else {
                return nil
            }

            let exposure = ValidatorExposure(
                total: item.1.total,
                own: item.1.own,
                others: others.others
            )

            return EraValidatorInfo(
                accountId: item.0,
                exposure: exposure,
                prefs: pref
            )
        }

        let snapshot = EraStakersInfo(
            activeEra: activeEra,
            validators: validators
        )

        completion(snapshot)
    }

    private func createPrefsWrapper(
        activeEra: EraIndex,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> BaseOperation<[Data: StorageResponse<ValidatorPrefs>]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return BaseOperation.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let requestFactory = AsyncStorageRequestDefault()

        return AwaitOperation<[Data: StorageResponse<ValidatorPrefs>]> {
            guard let runtimeService = self.chainRegistry.getRuntimeProvider(for: self.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let pathKey = try StorageKeyFactory().createStorageKey(moduleName: StorageCodingPath.erasPrefs.moduleName, storageName: StorageCodingPath.erasPrefs.itemName)
            let era = try NMapKeyParam(value: StringScaleMapper(value: activeEra)).encode(encoder: codingFactory.createEncoder(), type: "u32")
            let eraKey = try StorageHasher.twox64Concat.hash(data: era)
            let key = pathKey + eraKey
            let response: [StorageResponse<ValidatorPrefs>] = try await requestFactory.queryItemsByPrefix(
                engine: connection,
                keys: [key],
                factory: codingFactory,
                storagePath: .erasPrefs
            )

            let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

            let metadataByAccountId = try await response.asyncReduce([Data: StorageResponse<ValidatorPrefs>]()) { result, item in
                var map = result
                let key: ErasStakersOverviewKey = try await keyExtractor.extractKey(storageKey: item.key, storagePath: .erasPrefs, type: .erasStakersOverviewKey)
                map[key.accountId] = item

                return map
            }

            return metadataByAccountId
        }
    }

    private func createStakersOverviewWrapper(
        activeEra: UInt32,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AwaitOperation<[Data: StorageResponse<ValidatorExposureMetadata>]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return AwaitOperation<[Data: StorageResponse<ValidatorExposureMetadata>]>.createWithError(ChainRegistryError.runtimeMetadaUnavailable) as! AwaitOperation<[Data: StorageResponse<ValidatorExposureMetadata>]>
        }

        let requestFactory = AsyncStorageRequestDefault()

        return AwaitOperation<[Data: StorageResponse<ValidatorExposureMetadata>]> {
            guard let runtimeService = self.chainRegistry.getRuntimeProvider(for: self.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let pathKey = try StorageKeyFactory().createStorageKey(moduleName: StorageCodingPath.erasStakersOverview.moduleName, storageName: StorageCodingPath.erasStakersOverview.itemName)
            let era = try NMapKeyParam(value: StringScaleMapper(value: activeEra)).encode(encoder: codingFactory.createEncoder(), type: "u32")
            let eraKey = try StorageHasher.twox64Concat.hash(data: era)
            let key = pathKey + eraKey
            let response: [StorageResponse<ValidatorExposureMetadata>] = try await requestFactory.queryItemsByPrefix(
                engine: connection,
                keys: [key],
                factory: codingFactory,
                storagePath: .erasStakersOverview
            )

            let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

            let metadataByAccountId = try await response.asyncReduce([Data: StorageResponse<ValidatorExposureMetadata>]()) { result, item in
                var map = result
                let key: ErasStakersOverviewKey = try await keyExtractor.extractKey(storageKey: item.key, storagePath: .erasStakersOverview, type: .erasStakersOverviewKey)
                map[key.accountId] = item

                return map
            }

            return metadataByAccountId
        }
    }

    private func createValidatorOthersWrapper(
        activeEra: UInt32,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AwaitOperation<[Data: ValidatorExposurePage]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return AwaitOperation<[Data: ValidatorExposurePage]>.createWithError(ChainRegistryError.runtimeMetadaUnavailable) as! AwaitOperation<[Data: ValidatorExposurePage]>
        }

        let requestFactory = AsyncStorageRequestDefault()

        return AwaitOperation<[Data: ValidatorExposurePage]> {
            guard let runtimeService = self.chainRegistry.getRuntimeProvider(for: self.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let pathKey = try StorageKeyFactory().createStorageKey(moduleName: StorageCodingPath.erasStakersPaged.moduleName, storageName: StorageCodingPath.erasStakersPaged.itemName)
            let era = try NMapKeyParam(value: StringScaleMapper(value: activeEra)).encode(encoder: codingFactory.createEncoder(), type: "u32")
            let eraKey = try StorageHasher.twox64Concat.hash(data: era)
            let key = pathKey + eraKey
            let response: [StorageResponse<ValidatorExposurePage>] = try await requestFactory.queryItemsByPrefix(
                engine: connection,
                keys: [key],
                factory: codingFactory,
                storagePath: .erasStakersPaged
            )

            let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

            let othersByAccountId = try await response.asyncReduce([Data: ValidatorExposurePage]()) { result, item in
                var map = result
                let key: ErasStakersPagedKey = try await keyExtractor.extractKey(storageKey: item.key, storagePath: .erasStakersPaged, type: .erasStakersPagedKey)
                if let existingValidator = result[key.accountId], let value = item.value {
                    map[key.accountId] = value + existingValidator
                } else {
                    map[key.accountId] = item.value
                }

                return map
            }

            return othersByAccountId
        }
    }

    private func createRemoteValidatorsFetch(
        for prefixKey: Data,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[String]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let operation: BaseOperation<[StorageResponse<ValidatorExposureMetadata>]> =
            chainStakingSettings.queryItems(
                engine: connection,
                keyParams: { [prefixKey] },
                factory: { codingFactory },
                storagePath: .erasStakersOverview,
                using: AsyncStorageRequestDefault()
            )

        let mapOperation = ClosureOperation<[String]> {
            let exposures = try operation.extractNoCancellableResultData()
            return exposures.compactMap { $0.key.toHex() }
        }

        mapOperation.addDependency(operation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
    }

    private func createLocalExposurePrefixKey(
        for chainId: ChainModel.Id,
        activeEra: UInt32?
    ) throws -> String {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            .erasStakers,
            chainId: chainId
        )

        if let activeEra = activeEra {
            let encodedActiveEra = try activeEra.scaleEncoded()
            return localKey + encodedActiveEra.toHex()
        } else {
            return localKey
        }
    }

    private func createValidatorsSave(
        exposures: BaseOperation<[Data: StorageResponse<ValidatorExposureMetadata>]>,
        activeEra: UInt32
    ) -> BaseOperation<Void> {
        do {
            let baseLocalKey = try createLocalExposurePrefixKey(for: chainId, activeEra: nil)
            let activeEraSuffix = try activeEra.scaleEncoded().toHex()

            let filter = NSPredicate.filterByIdPrefix(baseLocalKey)
            let newRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
                storageFacade.createRepository(filter: filter)

            return newRepository.replaceOperation {
                let result = try exposures.extractNoCancellableResultData()
                return result.compactMap { item in
                    if let data = item.value.data {
                        let localId = baseLocalKey + activeEraSuffix + item.key.toHex()
                        return ChainStorageItem(identifier: localId, data: data)
                    } else {
                        return nil
                    }
                }
            }
        } catch {
            return BaseOperation.createWithError(error)
        }
    }

    private func handleRemoteUpdate(
        activeEra: UInt32,
        exposureResponse: [Data: StorageResponse<ValidatorExposureMetadata>],
        prefsResponse: [Data: StorageResponse<ValidatorPrefs>],
        others: [AccountId: ValidatorExposurePage],
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        let exposuresByAccountId = exposureResponse.reduce(into: [Data: ValidatorExposureMetadata]()) { partialResult, item in
            partialResult[item.key] = item.value.value
        }

        let prefsByAccountId = prefsResponse.reduce(into: [Data: ValidatorPrefs]()) { partialResult, item in
            partialResult[item.key] = item.value.value
        }
        updateValidators(
            activeEra: activeEra,
            exposures: exposuresByAccountId,
            prefs: prefsByAccountId,
            others: others,
            completion: completion
        )
    }

    private func updateFromRemote(
        activeEra: UInt32,
        codingFactory: RuntimeCoderFactoryProtocol,
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        let exposureWrapper = createStakersOverviewWrapper(activeEra: activeEra, codingFactory: codingFactory)
        let othersWrapper = createValidatorOthersWrapper(activeEra: activeEra, codingFactory: codingFactory)

        let prefsWrapper = createPrefsWrapper(
            activeEra: activeEra,
            codingFactory: codingFactory
        )

        let saveOperation = createValidatorsSave(
            exposures: exposureWrapper,
            activeEra: activeEra
        )

        saveOperation.addDependency(othersWrapper)
        saveOperation.addDependency(exposureWrapper)
        saveOperation.addDependency(prefsWrapper)

        let operations: [Operation] = {
            var array = [Operation]()
            array.append(prefsWrapper)
            array.append(exposureWrapper)
            array.append(othersWrapper)
            array.append(saveOperation)
            return array
        }()

        saveOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try exposureWrapper.extractNoCancellableResultData()
                    let others = try othersWrapper.extractNoCancellableResultData()
                    let prefs = try prefsWrapper.extractNoCancellableResultData()

                    self?.handleRemoteUpdate(
                        activeEra: activeEra,
                        exposureResponse: exposures,
                        prefsResponse: prefs,
                        others: others,
                        completion: completion
                    )
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func decodeLocalValidators(
        _ encodedItems: [ChainStorageItem],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[IdentifiableExposureMetadata]> {
        let accountIdLenght = chain.accountIdLenght
        let decodingOperation = StorageDecodingListOperation<ValidatorExposureMetadata>(path: .erasStakersOverview)
        decodingOperation.codingFactory = codingFactory
        decodingOperation.dataList = encodedItems.map(\.data)

        let mapOperation: BaseOperation<[IdentifiableExposureMetadata]> = ClosureOperation {
            let identifiers = try encodedItems.map { item in
                try Data(hexStringSSF: item.identifier).getAccountIdFromKey(accountIdLenght: accountIdLenght)
            }
            let validators = try decodingOperation.extractNoCancellableResultData()

            return Array(zip(identifiers, validators))
        }

        mapOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [decodingOperation])
    }

    private func updateFromLocal(
        validators: [ChainStorageItem],
        activeEra: UInt32,
        codingFactory: RuntimeCoderFactoryProtocol,
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        let localDecoder = decodeLocalValidators(validators, codingFactory: codingFactory)

        let prefs = createPrefsWrapper(
            activeEra: activeEra,
            codingFactory: codingFactory
        )
        let others = createValidatorOthersWrapper(
            activeEra: activeEra,
            codingFactory: codingFactory
        )

        let syncOperation = Operation()
        syncOperation.addDependency(prefs)
        syncOperation.addDependency(others)
        syncOperation.addDependency(localDecoder.targetOperation)

        syncOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try localDecoder.targetOperation.extractNoCancellableResultData()
                    let prefs = try prefs.extractNoCancellableResultData()
                    let others = try others.extractNoCancellableResultData()

                    let exposuresByAccountId = exposures.reduce(into: [Data: ValidatorExposureMetadata]()) { partialResult, item in
                        partialResult[item.0] = item.1
                    }
                    let prefsByAccountId = prefs.reduce(into: [Data: ValidatorPrefs]()) { partialResult, item in
                        partialResult[item.key] = item.value.value
                    }
                    self?.updateValidators(
                        activeEra: activeEra,
                        exposures: exposuresByAccountId,
                        prefs: prefsByAccountId,
                        others: others,
                        completion: completion
                    )
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        let operations = localDecoder.allOperations + [prefs] + [others] + [syncOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func preparePrefixKeyAndUpdateIfNeeded(activeEra: UInt32, completion: @escaping ((EraStakersInfo) -> Void)) {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let erasStakersKeyOperation = MapKeyEncodingOperation(
            path: .erasStakers,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [String(activeEra)]
        )

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
                case let .success(prefixKeys):
                    if let factory = erasStakersKeyOperation.codingFactory {
                        self?.updateIfNeeded(activeEra: activeEra, codingFactory: factory, completion: completion)
                    } else {
                        self?.logger?.warning("Can't find coding factory or eras key")
                    }
                case let .failure(error):
                    self?.logger?.error("Prefix key encoding error: \(error)")
                case .none:
                    self?.logger?.warning("Did cancel prefix key encoding")
                }
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, erasStakersKeyOperation],
            in: .transient
        )
    }

    private func updateIfNeeded(
        activeEra: UInt32,
        codingFactory: RuntimeCoderFactoryProtocol,
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        guard
            let localPrefixKey = try? createLocalExposurePrefixKey(
                for: chainId,
                activeEra: activeEra
            ) else {
            logger?.error("Can't create local storage key prefix key")
            return
        }

        let filter = NSPredicate.filterByIdPrefix(localPrefixKey)

        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository(filter: filter)

        let localValidatorsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        localValidatorsOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let validators = try localValidatorsOperation.extractNoCancellableResultData()

                    if validators.isEmpty {
                        self?.updateFromRemote(
                            activeEra: activeEra,
                            codingFactory: codingFactory,
                            completion: completion
                        )
                    } else {
                        self?.updateFromLocal(
                            validators: validators,
                            activeEra: activeEra,
                            codingFactory: codingFactory,
                            completion: completion
                        )
                    }
                } catch {
                    self?.logger?.error("Local fetch failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: [localValidatorsOperation], in: .transient)
    }

    func fetchEraStakersPaged(
        activeEra: UInt32,
        completion: @escaping ((EraStakersInfo) -> Void)
    ) {
        preparePrefixKeyAndUpdateIfNeeded(activeEra: activeEra, completion: completion)
    }
}
