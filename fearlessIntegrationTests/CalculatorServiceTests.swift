import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation
import FearlessUtils

class CalculatorServiceTests: XCTestCase {
    func testWestendCalculatorSetupWithoutCache() throws {
        measure {
            do {
                let storageFacade = SubstrateStorageTestFacade()
                try performServiceTest(
                    for: Chain.westend.genesisHash,
                    storageFacade: storageFacade,
                    assetPrecision: 12
                )
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testSingleWestend() throws {
        let storageFacade = SubstrateDataStorageFacade.shared

        do {
            try performServiceTest(
                for: Chain.westend.genesisHash,
                storageFacade: storageFacade,
                assetPrecision: 12
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testWestendCalculatorSetupWithCache() throws {
        let storageFacade = SubstrateDataStorageFacade.shared
        measure {
            do {
                try performServiceTest(
                    for: Chain.westend.genesisHash,
                    storageFacade: storageFacade,
                    assetPrecision: 12
                )
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testKusamaCalculatorSetupWithoutCache() throws {
        measure {
            do {
                let storageFacade = SubstrateStorageTestFacade()
                try performServiceTest(
                    for: Chain.kusama.genesisHash,
                    storageFacade: storageFacade,
                    assetPrecision: 12
                )
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testSingleKusama() throws {
        let storageFacade = SubstrateDataStorageFacade.shared

        do {
            try performServiceTest(
                for: Chain.kusama.genesisHash,
                storageFacade: storageFacade,
                assetPrecision: 12
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testKusamaCalculatorSetupWithCache() throws {
        let storageFacade = SubstrateDataStorageFacade.shared
        measure {
            do {
                try performServiceTest(
                    for: Chain.kusama.genesisHash,
                    storageFacade: storageFacade,
                    assetPrecision: 12
                )
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testDecodeLocalEncodedValidatorsForWestend() {
        performTestDecodeLocalEncodedValidators(for: Chain.westend.genesisHash)
    }

    func testDecodeLocalEncodedValidatorsForKusama() {
        performTestDecodeLocalEncodedValidators(for: Chain.kusama.genesisHash)
    }

    func testFetchingLocalEncodedValidatorsForKusama() {
        do {
            let storageFacade = SubstrateDataStorageFacade.shared
            let chainId = Chain.kusama.genesisHash

            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let codingFactory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)

            guard let era = try fetchActiveEra(
                    for: chainId,
                    storageFacade: storageFacade,
                    codingFactory: codingFactory
            ) else {
                XCTFail("No era found")
                return
            }

            measure {
                do {
                    let items = try fetchLocalEncodedValidators(
                        for: chainId, era: era,
                        coderFactory: codingFactory,
                        storageFacade: storageFacade
                    )
                    XCTAssert(!items.isEmpty)
                } catch {
                    XCTFail("Unexpected error \(error)")
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }


    func testFetchingLocalElectedValidatorsForKusama() {
        let storageFacade = SubstrateDataStorageFacade.shared
        let chainId = Chain.kusama.genesisHash

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        measure {
            do {
                let codingFactory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)
                try performDatabaseTest(for: chainId,
                                        storageFacade: storageFacade,
                                        codingFactory: codingFactory)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testCoderFactoryFetchForKusama() {
        let chainId = Chain.kusama.genesisHash

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(
            with: SubstrateDataStorageFacade.shared
        )

        measure {
            do {
                let _ = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testCoderFactoryFetchAndActiveEraForKusama() {
        let chainId = Chain.kusama.genesisHash
        let facade = SubstrateDataStorageFacade.shared

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(
            with: facade
        )

        measure {
            do {
                let factory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)
                let _ = try fetchActiveEra(for: chainId, storageFacade: facade, codingFactory: factory)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testValidatorPrefsFetchForKusama() {
        do {
            let chainId = Chain.kusama.genesisHash
            let storageFacade = SubstrateDataStorageFacade.shared

            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let connection = chainRegistry.getConnection(for: chainId)!

            let factory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)

            guard let activeEra = try fetchActiveEra(for: chainId,
                                                     storageFacade: storageFacade,
                                                     codingFactory: factory) else {
                XCTFail("No era")
                return
            }

            let items = try fetchLocalEncodedValidators(for: chainId,
                                                        era: activeEra,
                                                        coderFactory: factory,
                                                        storageFacade: storageFacade)

            let identifiers: [Data] = try items.map { item in
                let key = try Data(hexString: item.identifier)
                return key.getAccountIdFromKey()
            }

            measure {
                do {
                    let prefs = try fetchRemoteEncodedValidatorPrefs(identifiers,
                                                                     era: activeEra,
                                                                     engine: connection,
                                                                     codingFactory: factory)
                    XCTAssertEqual(prefs.count, identifiers.count)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testKusamaCalculatorSetupWithCacheAlternative() throws {
        measure {
            do {
                let chainId = Chain.kusama.genesisHash
                let storageFacade = SubstrateDataStorageFacade.shared

                let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

                let connection = chainRegistry.getConnection(for: chainId)!

                let factory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)

                guard let activeEra = try fetchActiveEra(for: chainId,
                                                         storageFacade: storageFacade,
                                                         codingFactory: factory) else {
                    XCTFail("No era")
                    return
                }

                let items = try fetchLocalEncodedValidators(for: chainId,
                                                            era: activeEra,
                                                            coderFactory: factory,
                                                            storageFacade: storageFacade)

                _ = try decodeEncodedValidators(items, codingFactory: factory)

                let identifiers: [Data] = try items.map { item in
                    let key = try Data(hexString: item.identifier)
                    return key.getAccountIdFromKey()
                }

                let prefs = try fetchRemoteEncodedValidatorPrefs(identifiers,
                                                                 era: activeEra,
                                                                 engine: connection,
                                                                 codingFactory: factory)
                XCTAssertEqual(prefs.count, identifiers.count)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testSubscriptionToEra() {
        measure {
            do {
                let chainId = Chain.kusama.genesisHash
                let storageFacade = SubstrateDataStorageFacade.shared
                let syncQueue = DispatchQueue(label: "test.\(UUID().uuidString)")

                let localFactory = LocalStorageKeyFactory()

                let path = StorageCodingPath.activeEra
                let localKey = try localFactory.createFromStoragePath(path, chainId: chainId)
                let eraDataProvider = SubstrateDataProviderFactory(facade: storageFacade,
                                                                   operationManager: OperationManager())
                    .createStorageProvider(for: localKey)

                let expectation = XCTestExpectation()

                let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { changes in
                    let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                        switch item {
                        case .insert(let newItem), .update(let newItem):
                            return newItem
                        case .delete:
                            return nil
                        }
                    }

                    if finalValue != nil {
                        expectation.fulfill()
                    }
                }

                let failureClosure: (Error) -> Void = { (error) in
                    XCTFail("Unexpected error: \(error)")
                    expectation.fulfill()
                }

                let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                                waitsInProgressSyncOnAdd: false,
                                                                initialSize: 0,
                                                                refreshWhenEmpty: false)
                eraDataProvider.addObserver(self,
                                            deliverOn: syncQueue,
                                            executing: updateClosure,
                                            failing: failureClosure,
                                            options: options)

                wait(for: [expectation], timeout: 10.0)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: Private

    private func performDatabaseTest(for chainId: ChainModel.Id,
                                     storageFacade: StorageFacadeProtocol,
                                     codingFactory: RuntimeCoderFactoryProtocol) throws {
        let operationQueue = OperationQueue()

        guard let activeEra = try fetchActiveEra(for: chainId,
                                                 storageFacade: storageFacade,
                                                 codingFactory: codingFactory,
                                                 operationQueue: operationQueue) else {
            XCTFail("No active era")
            return
        }

        let localKey = try createEraStakersPrefixKey(for: chainId, era: activeEra)

        let filter = NSPredicate.filterByIdPrefix(localKey)

        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository(filter: filter)
        let anyRepository = AnyDataProviderRepository(repository)

        let localValidatorsWrapper =
            createLocalValidatorsWrapper(repository: anyRepository,
                                         codingFactory: codingFactory)

        operationQueue.addOperations(localValidatorsWrapper.allOperations, waitUntilFinished: true)

        let validators = try localValidatorsWrapper.targetOperation.extractNoCancellableResultData()

        XCTAssert(!validators.isEmpty)
    }

    private func createLocalValidatorsWrapper(repository: AnyDataProviderRepository<ChainStorageItem>,
                                              codingFactory: RuntimeCoderFactoryProtocol)
    -> CompoundOperationWrapper<[(Data, ValidatorExposure)]> {
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

        let mapOperation: BaseOperation<[(Data, ValidatorExposure)]> = ClosureOperation {
            let identifiers = try fetchOperation.extractNoCancellableResultData().map { item in
                try Data(hexString: item.identifier).getAccountIdFromKey()
            }
            let validators = try decodingOperation.extractNoCancellableResultData()

            return Array(zip(identifiers, validators))
        }

        mapOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: [fetchOperation, decodingOperation])
    }

    private func fetchRemoteEncodedValidatorPrefs(_ identifers: [Data],
                                                  era: UInt32,
                                                  engine: JSONRPCEngine,
                                                  codingFactory: RuntimeCoderFactoryProtocol,
                                                  queue: OperationQueue = OperationQueue()) throws
    -> [StorageResponse<ValidatorPrefs>] {
        let params1: () throws -> [String] = {
            Array(repeating: String(era), count: identifers.count)
        }

        let params2: () throws -> [Data] = {
            identifers.map { $0 }
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager()
        )

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> =
            requestFactory.queryItems(engine: engine,
                                      keyParams1: params1,
                                      keyParams2: params2,
                                      factory: { codingFactory },
                                      storagePath: .erasPrefs)

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)

        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchLocalEncodedValidators(for chainId: ChainModel.Id,
                                             era: UInt32,
                                             coderFactory: RuntimeCoderFactoryProtocol,
                                             storageFacade: StorageFacadeProtocol,
                                             queue: OperationQueue = OperationQueue()) throws
    -> [ChainStorageItem] {
        let localKey = try createEraStakersPrefixKey(for: chainId, era: era)

        let filter = NSPredicate.filterByIdPrefix(localKey)

        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository(filter: filter)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        queue.addOperations([fetchOperation], waitUntilFinished: true)

        return try fetchOperation.extractNoCancellableResultData()
    }

    private func decodeEncodedValidators(_ validators: [ChainStorageItem],
                                         codingFactory: RuntimeCoderFactoryProtocol,
                                         operationQueue: OperationQueue = OperationQueue()) throws
    -> [ValidatorExposure] {
        let decodingOperation = StorageDecodingListOperation<ValidatorExposure>(path: .erasStakers)
        decodingOperation.codingFactory = codingFactory
        decodingOperation.dataList = validators.map { $0.data }

        operationQueue.addOperations([decodingOperation], waitUntilFinished: true)
        return try decodingOperation.extractNoCancellableResultData()
    }

    private func fetchCoderFactory(
        for chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        queue: OperationQueue = OperationQueue()
    ) throws -> RuntimeCoderFactoryProtocol {
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        queue.addOperations([coderFactoryOperation], waitUntilFinished: true)

        return try coderFactoryOperation.extractNoCancellableResultData()
    }

    private func fetchActiveEra(
        for chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        codingFactory: RuntimeCoderFactoryProtocol,
        operationQueue: OperationQueue = OperationQueue()
    ) throws -> UInt32? {
        let localFactory = LocalStorageKeyFactory()

        let path = StorageCodingPath.activeEra

        let localKey = try localFactory.createFromStoragePath(path, chainId: chainId)

        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        let fetchOperation = repository.fetchOperation(by: localKey, options: RepositoryFetchOptions())

        let decodingOperation = StorageDecodingOperation<ActiveEraInfo>(path: .activeEra)
        decodingOperation.codingFactory = codingFactory

        decodingOperation.configurationBlock = {
            do {
                let eraInfo = try fetchOperation.extractNoCancellableResultData()
                decodingOperation.data = eraInfo?.data
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(fetchOperation)

        operationQueue.addOperations([fetchOperation, decodingOperation], waitUntilFinished: true)

        return try decodingOperation.extractNoCancellableResultData().index
    }

    private func createEraStakersPrefixKey(for chainId: ChainModel.Id, era: UInt32?) throws -> String {

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            .erasStakers,
            chainId: chainId
        )

        if let era = era {
            let encodedEra = try era.scaleEncoded()
            return localKey + encodedEra.toHex()
        } else {
            return localKey
        }
    }

    private func performTestDecodeLocalEncodedValidators(
        for chainId: ChainModel.Id
    ) {
        do {
            let storageFacade = SubstrateDataStorageFacade.shared

            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let codingFactory = try fetchCoderFactory(for: chainId, chainRegistry: chainRegistry)

            guard let era = try fetchActiveEra(for: chainId,
                                               storageFacade: storageFacade,
                                               codingFactory: codingFactory) else {
                XCTFail("No era found")
                return
            }

            let items = try fetchLocalEncodedValidators(for: chainId,
                                                        era: era,
                                                        coderFactory: codingFactory,
                                                        storageFacade: storageFacade)
            XCTAssert(!items.isEmpty)

            measure {
                do {
                    let decodedValidators = try decodeEncodedValidators(items, codingFactory: codingFactory)
                    XCTAssertEqual(decodedValidators.count, items.count)
                } catch {
                    XCTFail("Unexpected error \(error)")
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performServiceTest(
        for chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        assetPrecision: Int16
    ) throws {
        // given

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationManager = OperationManagerFacade.sharedManager

        let chainItemRepository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createChainStorageItemRepository()

        let remoteStakingSubcriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(chainItemRepository),
            operationManager: OperationManager(),
            logger: Logger.shared
        )

        let subscriptionId = remoteStakingSubcriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: operationManager
        )

        let validatorService = try serviceFactory.createEraValidatorService(for: chainId)
        validatorService.setup()

        let calculatorService = try serviceFactory.createRewardCalculatorService(
            for: chainId,
            assetPrecision: assetPrecision,
            validatorService: validatorService
        )

        calculatorService.setup()

        let operation = calculatorService.fetchCalculatorOperation()

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try operation.extractNoCancellableResultData()
                } catch {
                    XCTFail("unexpected error \(error)")
                }

                expectation.fulfill()
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)

        wait(for: [expectation], timeout: 60.0)

        remoteStakingSubcriptionService.detachFromGlobalData(
            for: subscriptionId!,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
