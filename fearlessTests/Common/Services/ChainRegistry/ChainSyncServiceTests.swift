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

        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [completionExpectation], timeout: 10)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let sortedLocalItems = (try localItemsOperation.extractNoCancellableResultData()).sorted {
            $0.identifier.lexicographicallyPrecedes($1.identifier)
        }

        let sortedRemoteItems = allItems.sorted {
            $0.identifier.lexicographicallyPrecedes($1.identifier)
        }

        XCTAssertEqual(sortedLocalItems, sortedRemoteItems)
    }
}
