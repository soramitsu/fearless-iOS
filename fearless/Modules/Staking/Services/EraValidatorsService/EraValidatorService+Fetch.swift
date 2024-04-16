import Foundation
import RobinHood
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

private typealias IdentifiableExposure = (Data, ValidatorExposure)

extension EraValidatorService {
    private func updateValidators(
        activeEra: UInt32,
        exposures: [IdentifiableExposure],
        prefs: [StorageResponse<ValidatorPrefs>]
    ) {
        guard activeEra == self.activeEra else {
            logger?.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        let keyedPrefs = prefs.reduce(into: [Data: ValidatorPrefs]()) { result, item in
            let accountId = item.key.getAccountIdFromKey(accountIdLenght: chain.accountIdLenght)
            result[accountId] = item.value
        }

        let validators: [EraValidatorInfo] = exposures.compactMap { item in
            guard let pref = keyedPrefs[item.0] else {
                return nil
            }

            let exposure = ValidatorExposure(
                total: item.1.total,
                own: item.1.own,
                others: item.1.others.sorted { $0.value > $1.value }
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

        didReceiveSnapshot(snapshot)
    }

    private func createPrefsWrapper(
        identifiersClosure: @escaping () throws -> [Data],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        return chainStakingSettings.queryItems(
            engine: connection,
            keyParams: identifiersClosure,
            factory: { codingFactory },
            storagePath: .validatorPrefs,
            using: requestFactory
        )
    }

    private func createExposureWrapper(
        keysClosure: @escaping () throws -> [Data],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        return requestFactory.queryItems(
            engine: connection,
            keys: keysClosure,
            factory: { codingFactory },
            storagePath: .erasStakers
        )
    }

    private func createRemoteValidatorsFetch(for prefixKey: Data) -> BaseOperation<[String]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return BaseOperation.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let request = PagedKeysRequest(key: prefixKey.toHex(includePrefix: true))
        return JSONRPCOperation<PagedKeysRequest, [String]>(
            engine: connection,
            method: RPCMethod.getStorageKeysPaged,
            parameters: request
        )
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
        exposures: BaseOperation<[StorageResponse<ValidatorExposure>]>,
        activeEra: UInt32
    ) -> BaseOperation<Void> {
        let accountIdLenght = chain.accountIdLenght
        do {
            let baseLocalKey = try createLocalExposurePrefixKey(for: chainId, activeEra: nil)
            let activeEraSuffix = try activeEra.scaleEncoded().toHex()

            let filter = NSPredicate.filterByIdPrefix(baseLocalKey)
            let newRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
                storageFacade.createRepository(filter: filter)

            return newRepository.replaceOperation {
                let result = try exposures.extractNoCancellableResultData()
                return result.compactMap { item in
                    if let data = item.data {
                        let localId = baseLocalKey + activeEraSuffix +
                            item.key.getAccountIdFromKey(accountIdLenght: accountIdLenght).toHex()
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
        exposureResponse: [StorageResponse<ValidatorExposure>],
        prefsResponse: [StorageResponse<ValidatorPrefs>]
    ) {
        let exposures: [IdentifiableExposure] = exposureResponse.compactMap { item in
            guard let value = item.value else {
                return nil
            }

            let accountId = item.key.getAccountIdFromKey(accountIdLenght: chain.accountIdLenght)
            return (accountId, value)
        }

        updateValidators(
            activeEra: activeEra,
            exposures: exposures,
            prefs: prefsResponse
        )
    }

    private func updateFromRemote(
        activeEra: UInt32,
        prefixKey: Data,
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        let accountIdLenght = chain.accountIdLenght

        guard activeEra == self.activeEra else {
            logger?.warning("Wanted to fetch exposures but parameters changed. Cancelled.")
            return
        }

        let remoteValidatorIdsOperation = createRemoteValidatorsFetch(for: prefixKey)

        let keysClosure: () throws -> [Data] = {
            let hexKeys = try remoteValidatorIdsOperation.extractNoCancellableResultData()
            return try hexKeys.map { try Data(hexStringSSF: $0) }
        }

        let exposureWrapper = createExposureWrapper(keysClosure: keysClosure, codingFactory: codingFactory)

        exposureWrapper.allOperations.forEach { $0.addDependency(remoteValidatorIdsOperation) }

        let identifiersClosure: () throws -> [Data] = {
            let keys = try keysClosure()
            return keys.map { $0.getAccountIdFromKey(accountIdLenght: accountIdLenght) }
        }

        let prefsWrapper = createPrefsWrapper(
            identifiersClosure: identifiersClosure,
            codingFactory: codingFactory
        )

        prefsWrapper.allOperations.forEach { $0.addDependency(remoteValidatorIdsOperation) }

        let saveOperation = createValidatorsSave(
            exposures: exposureWrapper.targetOperation,
            activeEra: activeEra
        )

        saveOperation.addDependency(exposureWrapper.targetOperation)
        saveOperation.addDependency(prefsWrapper.targetOperation)

        let operations: [Operation] = {
            var array = [Operation]()
            array.append(contentsOf: exposureWrapper.allOperations)
            array.append(contentsOf: prefsWrapper.allOperations)
            array.append(remoteValidatorIdsOperation)
            array.append(saveOperation)
            return array
        }()

        saveOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try exposureWrapper.targetOperation.extractNoCancellableResultData()
                    let prefs = try prefsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.handleRemoteUpdate(
                        activeEra: activeEra,
                        exposureResponse: exposures,
                        prefsResponse: prefs
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
    ) -> CompoundOperationWrapper<[IdentifiableExposure]> {
        let accountIdLenght = chain.accountIdLenght
        let decodingOperation = StorageDecodingListOperation<ValidatorExposure>(path: .erasStakers)
        decodingOperation.codingFactory = codingFactory
        decodingOperation.dataList = encodedItems.map(\.data)

        let mapOperation: BaseOperation<[IdentifiableExposure]> = ClosureOperation {
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
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        let accountIdLenght = chain.accountIdLenght

        guard activeEra == self.activeEra else {
            logger?.warning("Wanted to fetch exposures but parameters changed. Cancelled.")
            return
        }

        let localDecoder = decodeLocalValidators(validators, codingFactory: codingFactory)

        let identifiersClosure = { try validators.map { try Data(hexStringSSF: $0.identifier).getAccountIdFromKey(accountIdLenght: accountIdLenght) } }

        let prefs = createPrefsWrapper(
            identifiersClosure: identifiersClosure,
            codingFactory: codingFactory
        )

        let syncOperation = Operation()
        syncOperation.addDependency(prefs.targetOperation)
        syncOperation.addDependency(localDecoder.targetOperation)

        syncOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let exposures = try localDecoder.targetOperation.extractNoCancellableResultData()
                    let prefs = try prefs.targetOperation.extractNoCancellableResultData()
                    self?.updateValidators(
                        activeEra: activeEra,
                        exposures: exposures,
                        prefs: prefs
                    )
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }
        }

        let operations = localDecoder.allOperations + prefs.allOperations + [syncOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func updateIfNeeded(
        activeEra: UInt32,
        prefixKey: Data,
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        guard activeEra == self.activeEra else {
            logger?.warning("Update triggered but parameters changed. Cancelled.")
            return
        }

        guard let localPrefixKey = try? createLocalExposurePrefixKey(
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
                            prefixKey: prefixKey,
                            codingFactory: codingFactory
                        )
                    } else {
                        self?.updateFromLocal(
                            validators: validators,
                            activeEra: activeEra,
                            codingFactory: codingFactory
                        )
                    }
                } catch {
                    self?.logger?.error("Local fetch failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: [localValidatorsOperation], in: .transient)
    }

    private func preparePrefixKeyAndUpdateIfNeeded(activeEra: UInt32) {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            return
        }
        guard activeEra == self.activeEra else {
            logger?.warning("Prefix key for formed but parameters changed. Cancelled.")
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
                    if
                        let factory = erasStakersKeyOperation.codingFactory,
                        let prefixKey = prefixKeys.first {
                        self?.updateIfNeeded(
                            activeEra: activeEra,
                            prefixKey: prefixKey,
                            codingFactory: factory
                        )
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

    private func handleEraDecodingResult(result: Result<ActiveEraInfo, Error>?) {
        switch result {
        case let .success(era):
            didReceiveActiveEra(era.index)
            preparePrefixKeyAndUpdateIfNeeded(activeEra: era.index)
        case let .failure(error):
            logger?.error("Did receive era decoding error: \(error)")
        case .none:
            logger?.warning("Error decoding operation canceled")
        }
    }

    func didUpdateActiveEraItem(_ eraItem: ChainStorageItem?) {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ConvenienceError(error: ChainRegistryError.runtimeMetadaUnavailable.localizedDescription).localizedDescription)
            return
        }

        guard let eraItem = eraItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<ActiveEraInfo>(
            path: .activeEra,
            data: eraItem.data
        )
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
                self?.handleEraDecodingResult(result: decodingOperation.result)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }
}
