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

    func testCalculateRewardPayouts() {
        do {
            let settings = InMemorySettingsManager()
            let chain = Chain.westend
            let storageFacade = SubstrateDataStorageFacade.shared
            let queue = OperationQueue()

            try AccountCreationHelper.createAccountFromMnemonic(
                cryptoType: .sr25519,
                networkType: chain,
                keychain: InMemoryKeychain(),
                settings: settings
            )

            let runtimeService = try createRuntimeService(
                from: storageFacade,
                operationManager: OperationManagerFacade.sharedManager,
                chain: chain
            )

            runtimeService.setup()

            let webSocketService = createWebSocketService(
                storageFacade: storageFacade,
                settings: settings
            )
            webSocketService.setup()

            guard let engine = webSocketService.connection else {
                XCTFail("No engine")
                return
            }

            let factory = try fetchCoderFactory(
                runtimeService: runtimeService,
                storageFacade: storageFacade,
                queue: queue
            )

            guard let activeEra = try fetchActiveEra(
                    for: chain,
                    storageFacade: storageFacade,
                    codingFactory: factory,
                    operationQueue: queue
            ) else {
                XCTFail("No active era")
                return
            }

            guard let currentEra = try fetchUInt32Value(
                storagePath: .currentEra,
                engine: engine,
                codingFactory: factory,
                keys: { [try StorageKeyFactory().currentEra()] },
                queue: queue
            ) else {
                XCTFail("No current era")
                return
            }

            let historyDepth = try fetchUInt32Value(
                storagePath: .historyDepth,
                engine: engine,
                codingFactory: factory,
                keys: { [try StorageKeyFactory().historyDepth()] },
                queue: queue
            ) ?? 84

            do {
                let validatorStash = [
                    "5HoSDmKXBXeD5HBj5haVUmWsjQEcp7Tt2QmYbCd8vrkeBK4b",
                    "5GR6SK9cj6c9uMaqZPpkMqVK99vukoRvS68ELEU2fRJ3EcNR",
                    "5FR5YJy3uwcEkXkRaaqsgARJ4C74V1zA8C6DRAECderYFGRk",
                    "5CFPcUJgYgWryPaV1aYjSbTpbTLu42V32Ytw1L9rfoMAsfGh",
                    "5DUGF2j9PsCdQ9okZfRoiCgbSeq3TUEAwuHvBQ3qjX4Nz4oR",
                    "5FbpwTP4usJ7dCFvtwzpew6NfXhtkvZH1jY4h6UfLztyD3Ng",
                    "5E2kbY5TTqGo6PZmZccAr4nkK6zGMSn73Bocen2gGBZGkcus",
                    "5GNy7frYA4BwWpKwxKAFWt4eBsZ9oAvXrp9SyDj6qzJAaNzB",
                    "5C8Pev9UHEtBgd1XKhg38U4PC49Azx8v5uphtxjWiXwmpsc7"
                ]
                let nominatorStashAccount = "5DEwU2U97RnBHCpfwHMDfJC7pqAdfWaPFib9wiZcr2ephSfT"

                let controllers = validatorStash
                    .compactMap { accountId in
                        try? fetchController(
                            forStash: accountId,
                            chain: chain,
                            engine: engine,
                            codingFactory: factory,
                            queue: queue
                        )
                        .compactMap(\.value)
                    }
                    .flatMap { $0 }

                let ledgers = controllers
                    .compactMap { controller -> DyStakingLedger in
                        try! fetchLedger(
                            controller: controller,
                            chain: chain,
                            engine: engine,
                            codingFactory: factory,
                            queue: queue
                        )
                        .first!.value!
                    }

                let eras = Set<UInt32>(currentEra-historyDepth..<activeEra)

                let controllerUnclaimedRewardsErasStash = ledgers
                    .map { ledger -> (Data, [UInt32]) in
                        let claimedRewards = Set(ledger.claimedRewards.map(\.value))
                        return (ledger.stash, Array(eras.subtracting(claimedRewards)))
                    }

                let ownAccountId = try SS58AddressFactory().accountId(fromAddress: nominatorStashAccount, type: chain.addressType)
                let setOfValidators = try controllerUnclaimedRewardsErasStash
                    .reduce(into: [Data: [(UInt32, ValidatorExposure, BigUInt)]]()) { dict, tuple in
                        let (stashAccountId, unclaimedRewardsEras) = tuple
                        let exposures: [(UInt32, ValidatorExposure)] = try fetchValidatorProperties(
                            storagePath: .validatorExposureClipped,
                            stashAccountId: stashAccountId,
                            eras: unclaimedRewardsEras,
                            chain: chain,
                            engine: engine,
                            codingFactory: factory,
                            queue: queue
                        ).filter { _, exposure in
                            exposure.others.contains(where: { $0.who == ownAccountId })
                        }

                        let prefs: [(UInt32, ValidatorPrefs)] = try fetchValidatorProperties(
                            storagePath: .erasPrefs,
                            stashAccountId: stashAccountId,
                            eras: unclaimedRewardsEras,
                            chain: chain,
                            engine: engine,
                            codingFactory: factory,
                            queue: queue
                        )

                        let res = unclaimedRewardsEras.reduce(into: [(UInt32, ValidatorExposure, BigUInt)](), { arr, era in
                            if
                                let exposure = exposures.first(where: { $0.0 == era }),
                                let pref = prefs.first(where: { $0.0 == era }) {
                                arr.append((era, exposure.1, pref.1.commission))
                            }
                        })
                        if !res.isEmpty {
                            dict[stashAccountId] = res
                        }
                    }

                let setOfEras: Set<UInt32> = setOfValidators
                    .values
                    .flatMap { $0 }
                    .map { $0.0 }
                    .reduce(into: Set<UInt32>(), { set, era in
                        set.insert(era)
                    })

                let totalRewardsPerEra: [UInt32: BigUInt] = setOfEras
                    .reduce(into: [UInt32: BigUInt](), { dict, era in
                        let totalReward = try! fetchTotalReward(
                            forEra: era,
                            engine: engine,
                            codingFactory: factory,
                            queue: queue
                        ).first!.value!.value
                        dict[era] = totalReward
                    })

                let rewardPointsByEra = setOfEras
                    .reduce(into: [UInt32: EraRewardPoints](), { dict, era in
                        let rewardPoints = try! fetchRewardPointsPerValidator(
                            forEra: era,
                            engine: engine,
                            codingFactory: factory
                        ).first!.value!
                        dict[era] = rewardPoints
                    })

                let rewardPerEraPerValidator = setOfValidators
                    .reduce(into: [Data: [UInt32: Decimal]]()) { resultDict, itemDict in
                        let stashAccount = itemDict.key
                        let array = itemDict.value

                        let validatorRewardPerEra = totalRewardsPerEra
                            .reduce(into: [UInt32: Decimal]()) { dict, totalRewardPerEra in
                                let (era, totalReward) = totalRewardPerEra
                                guard
                                    let rewardPoints = rewardPointsByEra[era],
                                    let totalRewardDecimal = Decimal.fromSubstrateAmount(
                                        totalReward,
                                        precision: chain.addressType.precision
                                    )
                                else { return }

                                let validatorPoint = rewardPoints
                                    .individual
                                    .first(where: { $0.accountId == stashAccount })
                                    .map(\.rewardPoint)!

                                let ratio = Decimal(validatorPoint) / Decimal(rewardPoints.total)

                                let validatorReward = totalRewardDecimal * ratio
                                dict[era] = validatorReward
                            }

                        let rewardOfNominatorWithinEras = validatorRewardPerEra
                            .reduce(into: [UInt32: Decimal]()) { dict, tuple in
                                let (era, validatorRewardPerEra) = tuple
                                guard
                                    let validatorComission = array
                                        .first(where: { $0.0 == era })
                                        .map({ Decimal.fromSubstratePerbill(value: $0.2)! }),
                                    let exposure = array
                                        .first(where: { $0.0 == era })
                                        .map({ $0.1 }),
                                    let totalStake = Decimal.fromSubstrateAmount(
                                        exposure.total,
                                        precision: chain.addressType.precision
                                    ),
                                    let nominatorStake = exposure
                                        .others
                                        .first(where: { $0.who == ownAccountId })
                                        .map({ Decimal.fromSubstrateAmount(
                                            $0.value,
                                            precision: chain.addressType.precision
                                        )!})
                                else { return }

                                let nominatorReward = validatorRewardPerEra
                                    * (Decimal(1) - validatorComission)
                                    * nominatorStake / totalStake
                                dict[era] = nominatorReward
                            }

                        resultDict[stashAccount] = rewardOfNominatorWithinEras
                    }
                XCTAssert(!rewardPerEraPerValidator.isEmpty)
            } catch {
                XCTFail("Unexpected     error: \(error)")
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

    private func fetchUInt32Value(
        storagePath: StorageCodingPath,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        keys: @escaping () throws -> [Data],
        queue: OperationQueue
    ) throws -> UInt32? {
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            requestFactory.queryItems(
                engine: engine,
                keys: keys,
                factory: { codingFactory },
                storagePath: storagePath
            )

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)
        let v = try queryWrapper.targetOperation.extractNoCancellableResultData()

        return v.first?.value?.value
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

    private func fetchController(
        forStash stash: String,
        chain: Chain,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        queue: OperationQueue
    ) throws -> [StorageResponse<String>] {
        let params: () throws -> [Data] = {
            [try SS58AddressFactory().accountId(fromAddress: stash, type: chain.addressType)]
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<String>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { codingFactory },
                storagePath: .controller
            )

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)
        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchValidatorProperties<T: Decodable>(
        storagePath: StorageCodingPath,
        stashAccountId: Data,
        eras: [UInt32],
        chain: Chain,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        queue: OperationQueue
    ) throws -> [(UInt32, T)] {
        let params1: () throws -> [String] = {
            eras.map(\.description)
        }

        let params2: () throws -> [Data] = {
            Array(repeating: stashAccountId, count: eras.count)
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let factory = StorageKeyFactory()
        let mapOperation = DoubleMapKeyEncodingOperation(
            path: storagePath,
            storageKeyFactory: factory,
            keyParams1: try params1(),
            keyParams2: try params2()
        )
        mapOperation.codingFactory = codingFactory

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams1: params1,
                keyParams2: params2,
                factory: { codingFactory },
                storagePath: storagePath
            )

        let closureOperation: BaseOperation<[(UInt32, T)]> = ClosureOperation {
            let result = try mapOperation.extractNoCancellableResultData()
            let dict = result
                .enumerated()
                .reduce(into: [Data: UInt32](), { dict, item in
                    let era = eras[item.offset]
                    dict[item.element] = era
                })
            let responses = try queryWrapper.targetOperation.extractNoCancellableResultData()
            return responses
                .compactMap { response in
                    if let value = response.value, let era = dict[response.key] {
                        return (era, value)
                    } else { return nil }
                }
        }
        ([mapOperation] + queryWrapper.allOperations)
            .forEach { operation in
                closureOperation.addDependency(operation)
            }

        queue.addOperations(
            [mapOperation] + queryWrapper.allOperations + [closureOperation],
            waitUntilFinished: true
        )

        return try closureOperation.extractNoCancellableResultData()
    }

    private func fetchLedger(
        controller: String,
        chain: Chain,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol,
        queue: OperationQueue
    ) throws -> [StorageResponse<DyStakingLedger>] {
        let params: () throws -> [Data] = {
            [try Data(hexString: controller)]
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<DyStakingLedger>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { codingFactory },
                storagePath: .stakingLedger
            )

        queue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)
        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }
}
