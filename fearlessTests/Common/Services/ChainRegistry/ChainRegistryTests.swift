import XCTest
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
@testable import fearless

final class ChainRegistryTests: XCTestCase {
    func testPerformColdBoot_whenSyncServicePublishesChains_thenRegistersRuntimeAndConnections() {
        let chains = ChainModelGenerator.generate(count: 3)
        let expectedChainIds = Set(chains.map(\.chainId))
        let fixture = makeFixture(chains: chains)

        fixture.registry.performColdBoot()

        XCTAssertTrue(waitUntil {
            Set(fixture.registry.availableChains.map(\.chainId)) == expectedChainIds
        })

        XCTAssertEqual(fixture.chainSyncService.syncUpCallCount, 1)
        XCTAssertEqual(fixture.chainsTypesSyncService.syncUpCallCount, 1)
        XCTAssertEqual(Set(fixture.runtimeProviderPool.setupChainIds), expectedChainIds)
        XCTAssertEqual(Set(fixture.runtimeSyncService.registeredChainIds), expectedChainIds)
        XCTAssertEqual(Set(fixture.specVersionSubscriptionFactory.subscriptions.keys), expectedChainIds)
        XCTAssertTrue(
            fixture.specVersionSubscriptionFactory.subscriptions.values.allSatisfy {
                $0.subscribeCallCount == 1
            }
        )

        chains.forEach { chain in
            XCTAssertNotNil(fixture.registry.getConnection(for: chain.chainId))
            XCTAssertNotNil(fixture.registry.getRuntimeProvider(for: chain.chainId))
        }
    }

    func testProcessRuntimeChainsTypesSyncCompleted_whenEventReceived_thenStoresTypesMap() {
        let fixture = makeFixture(chains: [])
        let versioningMap = [
            "chain-a": Data([0x01, 0x02]),
            "chain-b": Data([0x03, 0x04])
        ]

        fixture.registry.processRuntimeChainsTypesSyncCompleted(
            event: RuntimeChainsTypesSyncCompleted(versioningMap: versioningMap)
        )

        XCTAssertEqual(fixture.registry.chainsTypesMap, versioningMap)
    }

    func testPerformColdBoot_whenTonToggleSourceInjected_thenExposesSelectedTonChain() {
        let fixture = makeFixture(
            chains: [
                makeTonChain(chainId: "ton-mainnet", name: "TON", options: nil),
                makeTonChain(chainId: "ton-testnet", name: "TON Test", options: [.testnet])
            ],
            tonChainSelectionToggleSource: ChainRegistryTonToggleSourceStub(
                tonEnvListToggle: LocalListToggle.tonEnv.toggle()
            )
        )

        fixture.registry.performColdBoot()

        XCTAssertTrue(waitUntil {
            Set(fixture.registry.availableChains.map(\.chainId)) == ["ton-mainnet", "ton-testnet"]
        })
        XCTAssertEqual(fixture.registry.availableChainIds, Set(["ton-testnet"]))
    }

    private typealias Fixture = (
        registry: ChainRegistry,
        chainSyncService: RepositorySavingChainSyncService,
        runtimeProviderPool: RuntimeProviderPoolSpy,
        runtimeSyncService: RuntimeSyncServiceSpy,
        chainsTypesSyncService: ChainsTypesSyncServiceSpy,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactorySpy
    )

    private func makeFixture(
        chains: [ChainModel],
        tonChainSelectionToggleSource: TonChainSelection.ToggleSource = ChainRegistryTonToggleSourceStub(
            tonEnvListToggle: LocalListToggle.tonEnv
        )
    ) -> Fixture {
        let storageFacade = SubstrateStorageTestFacade()
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let repository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )
        let chainObserver = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )
        chainObserver.start { error in
            if let error {
                XCTFail("Unexpected chain observer error: \(error)")
            }
        }

        let chainProvider = StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let runtimeProviderPool = RuntimeProviderPoolSpy()
        let runtimeSyncService = RuntimeSyncServiceSpy()
        let chainsTypesSyncService = ChainsTypesSyncServiceSpy()
        let chainSyncService = RepositorySavingChainSyncService(
            chains: chains,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )
        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactorySpy()

        let registry = ChainRegistry(
            snapshotHotBootBuilder: SnapshotHotBootBuilderSpy(),
            runtimeProviderPool: runtimeProviderPool,
            connectionPools: [
                ConnectionPool(connectionFactory: ConnectionFactorySpy())
            ],
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            chainsTypesSyncService: chainsTypesSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory,
            networkIssuesCenter: NetworkIssuesCenterStub(),
            eventCenter: EventCenter(),
            tonChainSelectionToggleSource: tonChainSelectionToggleSource
        )

        return (
            registry,
            chainSyncService,
            runtimeProviderPool,
            runtimeSyncService,
            chainsTypesSyncService,
            specVersionSubscriptionFactory
        )
    }

    private func makeTonChain(
        chainId: ChainModel.Id,
        name: String,
        options: [ChainOptions]?
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://\(chainId).ton.example")!,
            name: "\(name) Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            icon: nil,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = Constants.defaultExpectationDuration,
        condition: @escaping () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return condition()
    }
}

private struct ChainRegistryTonToggleSourceStub: TonChainSelection.ToggleSource {
    let tonEnvListToggle: LocalListToggle
}

private final class RepositorySavingChainSyncService: ChainSyncServiceProtocol {
    private let chains: [ChainModel]
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    private(set) var syncUpCallCount = 0

    init(
        chains: [ChainModel],
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chains = chains
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func syncUp() {
        syncUpCallCount += 1
        let saveOperation = repository.saveOperation({ [chains] in chains }, { [] })
        operationQueue.addOperation(saveOperation)
    }
}

private final class RuntimeProviderPoolSpy: RuntimeProviderPoolProtocol {
    private var providers: [ChainModel.Id: RuntimeProviderProtocol] = [:]

    private(set) var setupChainIds: [ChainModel.Id] = []
    private(set) var destroyedChainIds: [ChainModel.Id] = []

    func setupRuntimeProvider(
        for chain: ChainModel,
        chainTypes _: Data?
    ) -> RuntimeProviderProtocol {
        setupChainIds.append(chain.chainId)

        let provider = providers[chain.chainId] ?? RegistryRuntimeProviderStub()
        providers[chain.chainId] = provider
        return provider
    }

    func setupHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem _: fearless.RuntimeMetadataItem,
        chainTypes _: Data
    ) -> RuntimeProviderProtocol {
        setupRuntimeProvider(for: chain, chainTypes: nil)
    }

    func destroyRuntimeProvider(for chainId: ChainModel.Id) {
        destroyedChainIds.append(chainId)
        providers[chainId] = nil
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        providers[chainId]
    }
}

private final class RuntimeSyncServiceSpy: RuntimeSyncServiceProtocol {
    private(set) var registeredChainIds: [ChainModel.Id] = []
    private(set) var unregisteredChainIds: [ChainModel.Id] = []
    private(set) var appliedRuntimeVersions: [ChainModel.Id: fearless.RuntimeVersion] = [:]

    func register(chain: ChainModel, with _: ChainConnection) {
        registeredChainIds.append(chain.chainId)
    }

    func unregister(chainId: ChainModel.Id) {
        unregisteredChainIds.append(chainId)
    }

    func apply(version: fearless.RuntimeVersion, for chainId: ChainModel.Id) {
        appliedRuntimeVersions[chainId] = version
    }

    func hasChain(with chainId: ChainModel.Id) -> Bool {
        registeredChainIds.contains(chainId)
    }

    func isChainSyncing(_: ChainModel.Id) -> Bool {
        false
    }
}

private final class ChainsTypesSyncServiceSpy: ChainsTypesSyncServiceProtocol {
    private(set) var syncUpCallCount = 0

    func syncUp() {
        syncUpCallCount += 1
    }
}

private final class SpecVersionSubscriptionFactorySpy: SpecVersionSubscriptionFactoryProtocol {
    private(set) var subscriptions: [ChainModel.Id: SpecVersionSubscriptionSpy] = [:]

    func createSubscription(
        for chainId: ChainModel.Id,
        connection _: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol {
        let subscription = SpecVersionSubscriptionSpy()
        subscriptions[chainId] = subscription
        return subscription
    }
}

private final class SpecVersionSubscriptionSpy: SpecVersionSubscriptionProtocol {
    private(set) var subscribeCallCount = 0
    private(set) var unsubscribeCallCount = 0

    func subscribe() {
        subscribeCallCount += 1
    }

    func unsubscribe() {
        unsubscribeCallCount += 1
    }
}

private final class SnapshotHotBootBuilderSpy: SnapshotHotBootBuilderProtocol {
    private(set) var startHotBootCallCount = 0

    func startHotBoot() {
        startHotBootCallCount += 1
    }
}

private final class ConnectionFactorySpy: ConnectionFactoryProtocol {
    private var retainedConnections: [ChainConnection] = []

    func createConnection(
        connectionName: String?,
        for urls: [URL],
        delegate _: WebSocketEngineDelegate
    ) throws -> ChainConnection {
        let connection = MockConnection()
        connection.connectionName = connectionName
        connection.url = urls.first
        retainedConnections.append(connection)
        return connection
    }
}

private final class NetworkIssuesCenterStub: NetworkIssuesCenterProtocol {
    func addIssuesListener(_: NetworkIssuesCenterListener, getExisting _: Bool) {}
    func removeIssuesListener(_: NetworkIssuesCenterListener) {}
    func forceNotify() {}
}

private enum ChainRegistryTestError: Error {
    case providerUnavailable
}

private final class RegistryRuntimeProviderStub: RuntimeProviderProtocol {
    var runtimeSpecVersion: SSFRuntimeCodingService.RuntimeSpecVersion = .defaultVersion
    var snapshot: SSFRuntimeCodingService.RuntimeSnapshot?

    func setup() {}
    func setupHot() {}
    func cleanup() {}

    func readySnapshot() async throws -> SSFRuntimeCodingService.RuntimeSnapshot {
        throw ChainRegistryTestError.providerUnavailable
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation<RuntimeCoderFactoryProtocol> {
            throw ChainRegistryTestError.providerUnavailable
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw ChainRegistryTestError.providerUnavailable
    }
}
