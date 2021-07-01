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
                try performServiceTest(for: .westend, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testSingleWestend() throws {
        let storageFacade = SubstrateDataStorageFacade.shared

        do {
            try performServiceTest(for: .westend, storageFacade: storageFacade)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testWestendCalculatorSetupWithCache() throws {
        let storageFacade = SubstrateDataStorageFacade.shared
        measure {
            do {
                try performServiceTest(for: .westend, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testKusamaCalculatorSetupWithoutCache() throws {
        measure {
            do {
                let storageFacade = SubstrateStorageTestFacade()
                try performServiceTest(for: .kusama, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testSingleKusama() throws {
        let storageFacade = SubstrateDataStorageFacade.shared

        do {
            try performServiceTest(for: .kusama, storageFacade: storageFacade)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testKusamaCalculatorSetupWithCache() throws {
        let storageFacade = SubstrateDataStorageFacade.shared
        measure {
            do {
                try performServiceTest(for: .kusama, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testDecodeLocalEncodedValidatorsForWestend() {
        performTestDecodeLocalEncodedValidators(for: .westend)
    }

    func testDecodeLocalEncodedValidatorsForKusama() {
        performTestDecodeLocalEncodedValidators(for: .kusama)
    }

    func testFetchingLocalEncodedValidatorsForKusama() {
        do {
            let storageFacade = SubstrateDataStorageFacade.shared
            let chain = Chain.kusama

            let codingFactory = try fetchCoderFactory(for: chain, storageFacade: storageFacade)

            guard let era = try fetchActiveEra(for: chain,
                                               storageFacade: storageFacade,
                                               codingFactory: codingFactory) else {
                XCTFail("No era found")
                return
            }

            measure {
                do {
                    let items = try fetchLocalEncodedValidators(for: chain,
                                                                era: era,
                                                                coderFactory: codingFactory,
                                                                storageFacade: storageFacade)
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
        let chain = Chain.kusama

        measure {
            do {
                let codingFactory = try fetchCoderFactory(for: chain, storageFacade: storageFacade)
                try performDatabaseTest(for: .kusama,
                                        storageFacade: storageFacade,
                                        codingFactory: codingFactory)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testCoderFactoryFetchForKusama() {
        measure {
            do {
                let _ = try fetchCoderFactory(for: .kusama,
                                              storageFacade: SubstrateDataStorageFacade.shared)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testCoderFactoryFetchAndActiveEraForKusama() {
        let facade = SubstrateDataStorageFacade.shared
        measure {
            do {
                let factory = try fetchCoderFactory(for: .kusama,
                                                    storageFacade: facade)
                let _ = try fetchActiveEra(for: .kusama,
                                           storageFacade: facade,
                                           codingFactory: factory)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testValidatorPrefsFetchForKusama() {
        do {
            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()
            let chain = Chain.kusama
            let storageFacade = SubstrateDataStorageFacade.shared

            try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                                networkType: chain,
                                                                keychain: keychain,
                                                                settings: settings)

            let operationManager = OperationManagerFacade.sharedManager

            let runtimeService = try createRuntimeService(from: storageFacade,
                                                          operationManager: operationManager,
                                                          chain: chain)

            runtimeService.setup()

            let webSocketService = createWebSocketService(
                storageFacade: storageFacade,
                runtimeService: runtimeService,
                operationManager: operationManager,
                settings: settings
            )

            webSocketService.setup()

            guard let engine = webSocketService.connection else {
                XCTFail("No engine")
                return
            }

            let factory = try fetchCoderFactory(for: chain, storageFacade: storageFacade)

            guard let activeEra = try fetchActiveEra(for: chain,
                                                     storageFacade: storageFacade,
                                                     codingFactory: factory) else {
                XCTFail("No era")
                return
            }

            let items = try fetchLocalEncodedValidators(for: chain,
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
                                                                     engine: engine,
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
                let settings = InMemorySettingsManager()
                let keychain = InMemoryKeychain()
                let chain = Chain.kusama
                let storageFacade = SubstrateDataStorageFacade.shared

                try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                                    networkType: chain,
                                                                    keychain: keychain,
                                                                    settings: settings)

                let operationManager = OperationManagerFacade.sharedManager

                let runtimeService = try createRuntimeService(from: storageFacade,
                                                              operationManager: operationManager,
                                                              chain: chain)

                runtimeService.setup()

                let webSocketService = createWebSocketService(
                    storageFacade: storageFacade,
                    runtimeService: runtimeService,
                    operationManager: operationManager,
                    settings: settings
                )

                webSocketService.setup()

                guard let engine = webSocketService.connection else {
                    XCTFail("No engine")
                    return
                }

                let factory = try fetchCoderFactory(for: chain, storageFacade: storageFacade)

                guard let activeEra = try fetchActiveEra(for: chain,
                                                         storageFacade: storageFacade,
                                                         codingFactory: factory) else {
                    XCTFail("No era")
                    return
                }

                let items = try fetchLocalEncodedValidators(for: chain,
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
                                                                 engine: engine,
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
                let chain = Chain.kusama
                let storageFacade = SubstrateDataStorageFacade.shared
                let syncQueue = DispatchQueue(label: "test.\(UUID().uuidString)")

                let localFactory = try ChainStorageIdFactory(chain: chain)

                let path = StorageCodingPath.activeEra
                let key = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                                   storageName: path.itemName)

                let localKey = localFactory.createIdentifier(for: key)
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

    private func performDatabaseTest(for chain: Chain,
                                     storageFacade: StorageFacadeProtocol,
                                     codingFactory: RuntimeCoderFactoryProtocol) throws {
        let operationQueue = OperationQueue()

        guard let activeEra = try fetchActiveEra(for: chain,
                                                 storageFacade: storageFacade,
                                                 codingFactory: codingFactory,
                                                 operationQueue: operationQueue) else {
            XCTFail("No active era")
            return
        }

        guard let prefixKey = try createEraStakersPrefixKey(for: chain,
                                                            era: activeEra,
                                                            codingFactory: codingFactory,
                                                            queue: operationQueue) else {
            XCTFail("No prefix key")
            return
        }

        let localPrefixKey = try ChainStorageIdFactory(chain: chain)
            .createIdentifier(for: prefixKey)

        let filter = NSPredicate.filterByIdPrefix(localPrefixKey)

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

    private func fetchLocalEncodedValidators(for chain: Chain,
                                             era: UInt32,
                                             coderFactory: RuntimeCoderFactoryProtocol,
                                             storageFacade: StorageFacadeProtocol,
                                             queue: OperationQueue = OperationQueue()) throws
    -> [ChainStorageItem] {
        guard let prefixKey = try createEraStakersPrefixKey(for: chain,
                                                            era: era,
                                                            codingFactory: coderFactory) else {
            return []
        }

        let localPrefixKey = try ChainStorageIdFactory(chain: chain)
            .createIdentifier(for: prefixKey)

        let filter = NSPredicate.filterByIdPrefix(localPrefixKey)

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

    private func fetchCoderFactory(for chain: Chain,
                                   storageFacade: StorageFacadeProtocol,
                                   queue: OperationQueue = OperationQueue()) throws
    -> RuntimeCoderFactoryProtocol {
        let runtimeService = try createRuntimeService(from: storageFacade,
                                                      operationManager: OperationManager(),
                                                      chain: chain)

        runtimeService.setup()

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        queue.addOperations([coderFactoryOperation], waitUntilFinished: true)

        return try coderFactoryOperation.extractNoCancellableResultData()
    }

    private func fetchActiveEra(for chain: Chain,
                                storageFacade: StorageFacadeProtocol,
                                codingFactory: RuntimeCoderFactoryProtocol,
                                operationQueue: OperationQueue = OperationQueue()) throws -> UInt32? {
        let localFactory = try ChainStorageIdFactory(chain: chain)

        let path = StorageCodingPath.activeEra
        let key = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                           storageName: path.itemName)

        let localKey = localFactory.createIdentifier(for: key)

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

    private func createEraStakersPrefixKey(for chain: Chain,
                                           era: UInt32,
                                           codingFactory: RuntimeCoderFactoryProtocol,
                                           queue: OperationQueue = OperationQueue()) throws -> Data? {

        let erasStakersKeyOperation = MapKeyEncodingOperation(path: .erasStakers,
                                                              storageKeyFactory: StorageKeyFactory(),
                                                              keyParams: [String(era)])
        erasStakersKeyOperation.codingFactory = codingFactory

        queue.addOperations([erasStakersKeyOperation], waitUntilFinished: true)

        return try erasStakersKeyOperation.extractNoCancellableResultData().first
    }

    private func performTestDecodeLocalEncodedValidators(for chain: Chain) {
        do {
            let storageFacade = SubstrateDataStorageFacade.shared

            let codingFactory = try fetchCoderFactory(for: chain, storageFacade: storageFacade)

            guard let era = try fetchActiveEra(for: chain,
                                               storageFacade: storageFacade,
                                               codingFactory: codingFactory) else {
                XCTFail("No era found")
                return
            }

            let items = try fetchLocalEncodedValidators(for: chain,
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

    private func performServiceTest(for chain: Chain, storageFacade: StorageFacadeProtocol) throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = try createRuntimeService(from: storageFacade,
                                                      operationManager: operationManager,
                                                      chain: chain,
                                                      logger: Logger.shared)

        runtimeService.setup()

        let webSocketService = createWebSocketService(
            storageFacade: storageFacade,
            runtimeService: runtimeService,
            operationManager: operationManager,
            settings: settings
        )

        webSocketService.setup()

        let validatorService = createEraValidatorsService(storageFacade: storageFacade,
                                                          runtimeService: runtimeService,
                                                          operationManager: operationManager,
                                                          logger: Logger.shared)

        if let engine = webSocketService.connection {
            validatorService.update(to: chain, engine: engine)
        }

        validatorService.setup()

        let calculatorService = createCalculationService(storageFacade: storageFacade,
                                                         eraValidatorService: validatorService,
                                                         runtimeService: runtimeService,
                                                         operationManager: operationManager)
        calculatorService.update(to: chain)
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
    }

    private func createRuntimeService(from storageFacade: StorageFacadeProtocol,
                                      operationManager: OperationManagerProtocol,
                                      chain: Chain,
                                      logger: LoggerProtocol? = nil) throws
    -> RuntimeRegistryService {
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                          directoryPath: runtimeDirectory)

        return RuntimeRegistryService(chain: chain,
                                      metadataProviderFactory: providerFactory,
                                      dataOperationFactory: DataOperationFactory(),
                                      filesOperationFacade: filesRepository,
                                      operationManager: operationManager,
                                      eventCenter: EventCenter.shared,
                                      logger: logger)
    }

    private func createWebSocketService(storageFacade: StorageFacadeProtocol,
                                        runtimeService: RuntimeCodingServiceProtocol,
                                        operationManager: OperationManagerProtocol,
                                        settings: SettingsManagerProtocol
    ) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: address)
        let factory = WebSocketSubscriptionFactory(
            storageFacade: storageFacade,
            runtimeService: runtimeService,
            operationManager: operationManager
        )
        return WebSocketService(settings: settings,
                                connectionFactory: WebSocketEngineFactory(),
                                subscriptionsFactory: factory,
                                applicationHandler: ApplicationHandler())
    }

    private func createEraValidatorsService(storageFacade: StorageFacadeProtocol,
                                            runtimeService: RuntimeCodingServiceProtocol,
                                            operationManager: OperationManagerProtocol,
                                            logger: LoggerProtocol? = nil)
    -> EraValidatorService {
        let factory = SubstrateDataProviderFactory(facade: storageFacade, operationManager: operationManager)
        return EraValidatorService(storageFacade: storageFacade,
                                   runtimeCodingService: runtimeService,
                                   providerFactory: factory,
                                   operationManager: operationManager,
                                   eventCenter: EventCenter.shared,
                                   logger: logger)
    }

    private func createCalculationService(storageFacade: StorageFacadeProtocol,
                                          eraValidatorService: EraValidatorServiceProtocol,
                                          runtimeService: RuntimeCodingServiceProtocol,
                                          operationManager: OperationManagerProtocol,
                                          logger: LoggerProtocol? = nil) -> RewardCalculatorService {
        let factory = SubstrateDataProviderFactory(facade: storageFacade, operationManager: operationManager)
        return RewardCalculatorService(eraValidatorsService: eraValidatorService,
                                       logger: logger,
                                       operationManager: operationManager,
                                       providerFactory: factory,
                                       runtimeCodingService: runtimeService,
                                       storageFacade: storageFacade)
    }
}
