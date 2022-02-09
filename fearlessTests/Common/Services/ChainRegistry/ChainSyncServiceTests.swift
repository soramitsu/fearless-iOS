import XCTest
@testable import fearless
import RobinHood
import Cuckoo

class ChainSyncServiceTests: XCTestCase {

    func testFetchedChainListApplied() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()

        let chainService = ChainSyncService(
            url: URL(string: "https://github.com")!,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let newItems = ChainModelGenerator.generate(count: 8)
        let updatedItems = ChainModelGenerator.generate(count: 5)
        let deletedItems = ChainModelGenerator.generate(count: 3)
        let allItems = updatedItems + deletedItems + newItems

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                let responseData = try! JSONEncoder().encode(allItems)
                return BaseOperation.createWithResult(responseData)
            }
        }

        let repositoryPresetOperation = repository.saveOperation({
            updatedItems
        }, {
            deletedItems.map { $0.identifier }
        })

        operationQueue.addOperations([repositoryPresetOperation], waitUntilFinished: true)

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItems = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(chainService.isSyncing, false)
        XCTAssertEqual(Set(localItems), Set(allItems))
    }

    func testSyncIsRetriedAfterFailure() {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()

        let chainService = ChainSyncService(
            url: URL(string: "https://github.com")!,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let newItems = ChainModelGenerator.generate(count: 8)
        let responseData = try! JSONEncoder().encode(newItems)
        let failureOperation = BaseOperation<Data>.createWithError(
            BaseOperationError.unexpectedDependentResult
        )
        let successOperation = BaseOperation.createWithResult(responseData)

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).thenReturn(failureOperation, successOperation)
        }

        let failureExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidFail {
                    failureExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [failureExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        XCTAssertEqual(chainService.isSyncing, false)
        XCTAssertEqual(chainService.retryAttempt, 0)
    }
}
