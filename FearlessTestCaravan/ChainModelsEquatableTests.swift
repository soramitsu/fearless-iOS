import XCTest
import SSFChainRegistry
import SSFNetwork
import RobinHood
import SoraFoundation
@testable import fearless

final class ChainSyncServiceTests: XCTestCase, EventVisitorProtocol {

    private var service: fearless.ChainSyncService?
    private let eventCenter = EventCenter.shared

    private var rootInteractorExpectation: XCTestExpectation?
    private var testExpectation: XCTestExpectation?
    private var newOrUpdatedChainsCount: Int?
    private var removedChainsCount: Int?

    override func setUpWithError() throws {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let chainRepositoryFactory = ChainRepositoryFactory(storageFacade: repositoryFacade)
        let chainRepository = chainRepositoryFactory.createRepository()

        let syncService = SSFChainRegistry.ChainSyncService(
            chainsUrl: ApplicationConfig.shared.chainsSourceUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory()
        )

        let chainSyncService = ChainSyncService(
            syncService: syncService,
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.syncQueue,
            logger: Logger.shared,
            applicationHandler: ApplicationHandler()
        )
        fearless.ChainSyncService.fetchLocalData = true
        service = chainSyncService

        eventCenter.add(observer: self, dispatchIn: nil)
    }

    override func tearDownWithError() throws {
        service = nil
        newOrUpdatedChainsCount = nil
        removedChainsCount = nil
    }

    func testEquatable() throws {
        rootInteractorExpectation = XCTestExpectation()
        wait(for: [rootInteractorExpectation].compactMap { $0 }, timeout: 1)
        service?.syncUp()
        testExpectation = XCTestExpectation()
        wait(for: [testExpectation].compactMap { $0 }, timeout: 1)
        XCTAssertEqual(newOrUpdatedChainsCount, 0)
        XCTAssertEqual(removedChainsCount, 0)
    }

    // MARK: - EventVisitorProtocol

    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        if let rootInteractorExpectation {
            rootInteractorExpectation.fulfill()
        }
        if let testExpectation {
            testExpectation.fulfill()
            newOrUpdatedChainsCount = event.newOrUpdatedChains.count
            removedChainsCount = event.removedChains.count
        }
    }
}
