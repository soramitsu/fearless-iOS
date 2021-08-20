import XCTest
@testable import fearless
import RobinHood
import Cuckoo

class ChainRegistryTests: XCTestCase {
    func testSetupCompletion() throws {
        // given

        let runtimeProviderPool = MockRuntimeProviderPoolProtocol()
        let connectionPool = MockConnectionPoolProtocol()
        let specVersionSubscriptionFactory = MockSpecVersionSubscriptionFactoryProtocol()
        let runtimeSyncService = MockRuntimeSyncServiceProtocol()

        stub(runtimeSyncService) { stub in
            stub.register(chain: any(), with: any()).thenDoNothing()
            stub.unregister(chainId: any()).thenDoNothing()
        }

        let commonTypesSyncService = MockCommonTypesSyncServiceProtocol()

        stub(commonTypesSyncService) { stub in
            stub.syncUp().thenDoNothing()
        }

        let dataOperationFactory = MockDataOperationFactoryProtocol()

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            stub.notify(with: any()).thenDoNothing()
        }

        let chainCount = 10
        let expectedChains = ChainModelGenerator.generate(count: chainCount)
        let expectedChainIds = Set(expectedChains.map { $0.chainId })
        let chainsData = try JSONEncoder().encode(expectedChains)

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).thenReturn(BaseOperation.createWithResult(chainsData))
        }

        stub(runtimeProviderPool) { stub in
            let runtimeProvider = MockRuntimeProviderProtocol()
            stub.setupRuntimeProvider(for: any()).thenReturn(runtimeProvider)
            stub.getRuntimeProvider(for: any()).thenReturn(runtimeProvider)
        }

        stub(connectionPool) { stub in
            let connection = MockConnection()
            stub.setupConnection(for: any()).thenReturn(connection)
            stub.getConnection(for: any()).thenReturn(connection)
        }

        let mockSubscription = MockSpecVersionSubscriptionProtocol()
        stub(mockSubscription) { stub in
            stub.subscribe().thenDoNothing()
            stub.unsubscribe().thenDoNothing()
        }

        stub(specVersionSubscriptionFactory) { stub in
            stub.createSubscription(for: any(), connection: any()).thenReturn(mockSubscription)
        }

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let chainSyncService = ChainSyncService(
            url: URL(string: "https://google.com")!,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        let chainObserver = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )

        chainObserver.start { error in
            if let error = error {
                Logger.shared.error("Chain database observer unexpectedly failed: \(error)")
            }
        }

        let chainProvider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )

        let registry = ChainRegistry(
            runtimeProviderPool: runtimeProviderPool,
            connectionPool: connectionPool,
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            commonTypesSyncService: commonTypesSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory
        )

        registry.syncUp()

        // when

        var setupChainIds = Set<ChainModel.Id>()

        let expectation = XCTestExpectation()

        registry.chainsSubscribe(self, runningInQueue: .main) { changes in
            guard !changes.isEmpty else {
                return
            }

            changes.forEach { change in
                if case let .insert(item) = change {
                    setupChainIds.insert(item.chainId)
                }
            }

            expectation.fulfill()
        }

        // then

        wait(for: [expectation], timeout: 10)

        XCTAssertEqual(expectedChainIds, setupChainIds)
        XCTAssertEqual(expectedChainIds, registry.availableChainIds)

        for chain in expectedChains {
            XCTAssertNotNil(registry.getConnection(for: chain.chainId))
            XCTAssertNotNil(registry.getRuntimeProvider(for: chain.chainId))
        }

        verify(runtimeSyncService, times(chainCount)).register(chain: any(), with: any())
    }
}
