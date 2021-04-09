import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation
import BigInt
import FearlessUtils
import IrohaCrypto

class RewardPayoutsServiceTests: XCTestCase {

    func testSubscriptionToHistoryDepth() {
        do {
            let chain = Chain.westend
            let storageFacade = SubstrateDataStorageFacade.shared

            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()

            try AccountCreationHelper.createAccountFromMnemonic(
                cryptoType: .sr25519,
                networkType: chain,
                keychain: keychain,
                settings: settings)

            let webSocketService = createWebSocketService(
                storageFacade: storageFacade,
                settings: settings)

            webSocketService.setup()

            let syncQueue = DispatchQueue(label: "test.\(UUID().uuidString)")

            let localFactory = try ChainStorageIdFactory(chain: chain)

            let path = StorageCodingPath.historyDepth
            let key = try StorageKeyFactory().createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName)

            let localKey = localFactory.createIdentifier(for: key)
            let historyDepthDataProvider = SubstrateDataProviderFactory(
                facade: storageFacade,
                operationManager: OperationManager())
                .createStorageProvider(for: localKey)

            let expectation = XCTestExpectation(description: "Obtained history depth")

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                    switch item {
                    case .insert(let newItem), .update(let newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                if let value = finalValue {
                    do {
                        let decoder = try ScaleDecoder(data: value.data)
                        let historyDepthValue = try UInt32(scaleDecoder: decoder)
                        XCTAssertEqual(historyDepthValue, 84)
                    } catch {
                        XCTFail("History depth decoding error: \(error)")
                    }

                    expectation.fulfill()
                }
            }

            let failureClosure: (Error) -> Void = { (error) in
                XCTFail("Unexpected error: \(error)")
                expectation.fulfill()
            }

            historyDepthDataProvider.addObserver(
                self,
                deliverOn: syncQueue,
                executing: updateClosure,
                failing: failureClosure,
                options: StreamableProviderObserverOptions.substrateSource())

            wait(for: [expectation], timeout: 10.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchTotalValidatorReward() {
        do {
            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()
            let chain = Chain.kusama
            let storageFacade = SubstrateDataStorageFacade.shared

            try AccountCreationHelper.createAccountFromMnemonic(
                cryptoType: .sr25519,
                networkType: chain,
                keychain: keychain,
                settings: settings)

            let operationManager = OperationManagerFacade.sharedManager

            let runtimeService = try createRuntimeService(
                from: storageFacade,
                operationManager: operationManager,
                chain: chain)

            runtimeService.setup()

            let webSocketService = createWebSocketService(
                storageFacade: storageFacade,
                settings: settings)
            webSocketService.setup()

            guard let engine = webSocketService.connection else {
                XCTFail("No engine")
                return
            }

            let factory = try fetchCoderFactory(runtimeService: runtimeService, storageFacade: storageFacade)

            guard let activeEra = try fetchActiveEra(
                    for: chain,
                    storageFacade: storageFacade,
                    codingFactory: factory) else {
                XCTFail("No era")
                return
            }

            let previousEra = activeEra - 1

            do {
                let totalReward = try fetchTotalReward(forEra: previousEra, engine: engine, codingFactory: factory)
                guard let totalRewardBigInt = totalReward.first?.value?.value else {
                    XCTFail("Unexpected totalRewardBigInt == nil")
                    return
                }
                let totalRewardDecimal = Decimal.fromSubstrateAmount(
                    totalRewardBigInt,
                    precision: chain.addressType.precision)

                XCTAssertNotNil(totalRewardDecimal)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRewardPointsPerValidator() {
        do {
            let settings = InMemorySettingsManager()
            let chain = Chain.kusama
            let storageFacade = SubstrateDataStorageFacade.shared

            try AccountCreationHelper.createAccountFromMnemonic(
                cryptoType: .sr25519,
                networkType: chain,
                keychain: InMemoryKeychain(),
                settings: settings)

            let runtimeService = try createRuntimeService(
                from: storageFacade,
                operationManager: OperationManagerFacade.sharedManager,
                chain: chain)

            runtimeService.setup()

            let webSocketService = createWebSocketService(
                storageFacade: storageFacade,
                settings: settings)
            webSocketService.setup()

            guard let engine = webSocketService.connection else {
                XCTFail("No engine")
                return
            }

            let factory = try fetchCoderFactory(runtimeService: runtimeService, storageFacade: storageFacade)

            guard let activeEra = try fetchActiveEra(
                    for: chain,
                    storageFacade: storageFacade,
                    codingFactory: factory) else {
                XCTFail("No era")
                return
            }

            let previousEra = activeEra - 1

            do {
                let rewardPoints = try fetchRewardPointsPerValidator(
                    forEra: previousEra,
                    engine: engine,
                    codingFactory: factory)

                guard let reward = rewardPoints.first?.value else {
                    XCTFail("RewardPoints is empty ")
                    return
                }
                XCTAssert(reward.total > 0)
                XCTAssert(reward.individual.count > 0)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchNominationHistory() {
        let subscanOperationFactory = SubscanOperationFactory()
        let queue = OperationQueue()
        let nominatorStashAccount = "5DEwU2U97RnBHCpfwHMDfJC7pqAdfWaPFib9wiZcr2ephSfT"
        let chain = Chain.westend

        do {

            let controllersByStaking = try fetchControllersByStakingModule(
                nominatorStashAccount: nominatorStashAccount,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory,
                queue: queue)

            let controllersByUtility = try fetchControllersByUtilityModule(
                nominatorStashAccount: nominatorStashAccount,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory,
                queue: queue)

            let setOfControllersWhichCouldEverMakeNominations =
                controllersByStaking.union(controllersByUtility)

            let validatorsByNominate = try fetchValidatorsByNominate(
                controllers: setOfControllersWhichCouldEverMakeNominations,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory,
                queue: queue)

            let validatorsByBatch = try fetchValidatorsByBatch(
                controllers: setOfControllersWhichCouldEverMakeNominations,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory,
                queue: queue)

            let validatorIdsSet = validatorsByNominate.union(validatorsByBatch)

            let expectedValidatorIdsSet = Set<String>([
                "5HoSDmKXBXeD5HBj5haVUmWsjQEcp7Tt2QmYbCd8vrkeBK4b",
                "5GR6SK9cj6c9uMaqZPpkMqVK99vukoRvS68ELEU2fRJ3EcNR",
                "5FR5YJy3uwcEkXkRaaqsgARJ4C74V1zA8C6DRAECderYFGRk",
                "5CFPcUJgYgWryPaV1aYjSbTpbTLu42V32Ytw1L9rfoMAsfGh",
                "5DUGF2j9PsCdQ9okZfRoiCgbSeq3TUEAwuHvBQ3qjX4Nz4oR",
                "5FbpwTP4usJ7dCFvtwzpew6NfXhtkvZH1jY4h6UfLztyD3Ng",
                "5E2kbY5TTqGo6PZmZccAr4nkK6zGMSn73Bocen2gGBZGkcus",
                "5GNy7frYA4BwWpKwxKAFWt4eBsZ9oAvXrp9SyDj6qzJAaNzB",
                "5C8Pev9UHEtBgd1XKhg38U4PC49Azx8v5uphtxjWiXwmpsc7"
            ])
            XCTAssertEqual(validatorIdsSet, expectedValidatorIdsSet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func fetchControllersByStakingModule(
        nominatorStashAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        queue: OperationQueue
    ) throws -> Set<String> {
        let bondControllers = try fetchExtrinsicsParams(
            moduleName: "staking",
            address: nominatorStashAccount,
            callName: "bond",
            subscanOperationFactory: subscanOperationFactory,
            queue: queue)

        let setControllers = try fetchExtrinsicsParams(
            moduleName: "staking",
            address: nominatorStashAccount,
            callName: "set_controller",
            subscanOperationFactory: subscanOperationFactory,
            queue: queue)

        let controllers = (bondControllers + setControllers)
            .compactMap { SubscanBondCall(callArgs: $0, chain: chain) }
            .map { $0.controller }
        return Set(controllers)
    }

    private func fetchControllersByUtilityModule(
        nominatorStashAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        queue: OperationQueue
    ) throws -> Set<String> {
        let batchControllers = try fetchExtrinsicsParams(
            moduleName: "utility",
            address: nominatorStashAccount,
            callName: "batch",
            subscanOperationFactory: subscanOperationFactory,
            queue: queue)

        let batchAllControllers = try fetchExtrinsicsParams(
            moduleName: "utility",
            address: nominatorStashAccount,
            callName: "batch_all",
            subscanOperationFactory: subscanOperationFactory,
            queue: queue)

        let controllers = (batchControllers + batchAllControllers)
            .compactMap { SubscanFindControllersBatchCall(callArgs: $0, chain: chain) }
            .flatMap { $0.controllers }
        return Set(controllers)
    }

    private func fetchValidatorsByNominate(
        controllers: Set<String>,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        queue: OperationQueue
    ) throws -> Set<String> {
        let validators = controllers
            .compactMap { address in
                try? fetchExtrinsicsParams(
                    moduleName: "staking",
                    address: address,
                    callName: "nominate",
                    subscanOperationFactory: subscanOperationFactory,
                    queue: queue
                )
                    .compactMap { SubscanNominateCall(callArgs: $0, chain: chain) }
                    .map(\.validatorAddresses)
            }
            .flatMap { $0 }
            .flatMap { $0 }
        return Set(validators)
    }

    private func fetchValidatorsByBatch(
        controllers: Set<String>,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        queue: OperationQueue
    ) throws -> Set<String> {
        let nominatorsBatch = controllers
            .compactMap { address -> [String] in
                let batch = try? fetchExtrinsicsParams(
                    moduleName: "utility",
                    address: address,
                    callName: "batch",
                    subscanOperationFactory: subscanOperationFactory,
                    queue: queue
                )

                let batchAll = try? fetchExtrinsicsParams(
                    moduleName: "utility",
                    address: address,
                    callName: "batch_all",
                    subscanOperationFactory: subscanOperationFactory,
                    queue: queue
                )

                return ((batch ?? []) + (batchAll ?? []))
                    .compactMap { SubscanFindValidatorsBatchCall(callArgs: $0, chain: chain) }
                    .flatMap(\.validatorAddresses)
            }
            .flatMap { $0 }

        return Set(nominatorsBatch)
    }

    private func fetchExtrinsicsParams(
        moduleName: String,
        address: String,
        callName: String,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        queue: OperationQueue
    ) throws -> [JSON] {
        let extrinsicsInfo = ExtrinsicsInfo(
            row: 100,
            page: 0,
            address: address,
            moduleName: moduleName,
            callName: callName)

        let url = WalletAssetId.westend.subscanUrl!
            .appendingPathComponent(SubscanApi.extrinsics)
        let fetchOperation = subscanOperationFactory.fetchExtrinsicsOperation(
            url,
            info: extrinsicsInfo
        )

        let queryWrapper = CompoundOperationWrapper(targetOperation: fetchOperation)
        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)

        guard let extrinsics = try queryWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics else { return [] }
        return extrinsics.compactMap { $0.params }
    }

    private func createWebSocketService(
        storageFacade: StorageFacadeProtocol,
        settings: SettingsManagerProtocol
    ) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(
            url: connectionItem.url,
            addressType: connectionItem.type,
            address: address)

        let factory = WebSocketSubscriptionFactory(storageFacade: storageFacade)
        return WebSocketService(
            settings: settings,
            connectionFactory: WebSocketEngineFactory(),
            subscriptionsFactory: factory,
            applicationHandler: ApplicationHandler())
    }

    private func createRuntimeService(
        from storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) throws -> RuntimeRegistryService {
        let providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(
            repository: FileRepository(),
            directoryPath: runtimeDirectory)

        return RuntimeRegistryService(
            chain: chain,
            metadataProviderFactory: providerFactory,
            dataOperationFactory: DataOperationFactory(),
            filesOperationFacade: filesRepository,
            operationManager: operationManager,
            eventCenter: EventCenter.shared,
            logger: logger)
    }

    private func fetchCoderFactory(
        runtimeService: RuntimeRegistryService,
        storageFacade: StorageFacadeProtocol,
        queue: OperationQueue = OperationQueue()
    ) throws -> RuntimeCoderFactoryProtocol {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        queue.addOperations([coderFactoryOperation], waitUntilFinished: true)
        return try coderFactoryOperation.extractNoCancellableResultData()
    }

    private func fetchActiveEra(
        for chain: Chain,
        storageFacade: StorageFacadeProtocol,
        codingFactory: RuntimeCoderFactoryProtocol,
        operationQueue: OperationQueue = OperationQueue()
    ) throws -> UInt32? {
        let localFactory = try ChainStorageIdFactory(chain: chain)

        let path = StorageCodingPath.activeEra
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: path.moduleName,
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

    private func fetchTotalReward(
        forEra era: UInt32,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        queue: OperationQueue = OperationQueue()
    ) throws -> [StorageResponse<StringScaleMapper<BigUInt>>] {
        let params: () throws -> [String] = {
            [String(era)]
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { codingFactory },
                storagePath: .totalValidatorReward)

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)

        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchRewardPointsPerValidator(
        forEra era: UInt32,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        queue: OperationQueue = OperationQueue()
    ) throws -> [StorageResponse<EraRewardPoints>] {
        let params: () throws -> [String] = {
            [String(era)]
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<EraRewardPoints>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { codingFactory },
                storagePath: .rewardPointsPerValidator)

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)
        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }
}
