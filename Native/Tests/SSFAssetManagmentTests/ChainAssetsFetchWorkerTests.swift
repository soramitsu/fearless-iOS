import RobinHood
import SSFAssetManagmentStorage
import SSFHelpers
import SSFModels
import SSFUtils
import XCTest

@testable import SSFAssetManagment

final class ChainAssetsFetchWorkerTests: XCTestCase {
    var worker: ChainAssetsFetchWorkerProtocol?

    override func setUp() {
        super.setUp()
        let chainRepository = AnyDataProviderRepository(prepareRepostory())
        let operationManager = OperationManager()

        worker = ChainAssetsFetchWorker(
            chainRepository: chainRepository,
            operationManager: operationManager
        )
    }

    override func tearDown() {
        super.tearDown()
        worker = nil
    }

    func testGetChainAssetsModels() async throws {
        // act
        let chains = await worker?.getChainAssetsModels()

        // assert
        XCTAssertNotNil(chains)
        XCTAssertEqual(chains?.count, 20)
    }
}

private extension ChainAssetsFetchWorkerTests {
    func prepareRepostory() -> CoreDataRepository<ChainModel, CDChain> {
        let facade = SubstrateStorageTestFacade()
        let apiKeyInjector = ApiKeyInjectorMock()
        let mapper = ChainModelMapper(apiKeyInjector: apiKeyInjector)

        let chains: [ChainModel] = (0 ..< 10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: UInt16(index),
                hasCrowdloans: true
            )
        }

        let repository: CoreDataRepository<ChainModel, CDChain> = facade
            .createRepository(mapper: AnyCoreDataMapper(mapper))
        let saveOperation = repository.saveOperation({ chains }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        return repository
    }
}


class ApiKeyInjectorMock: ApiKeyInjector {
    func getBlockExplorerKey(
        for _: SSFModels.BlockExplorerType,
        chainId _: SSFModels.ChainModel.Id
    ) -> String? {
        nil
    }

    func getNodeApiKey(for _: String, apiKeyName _: String) -> String? {
        nil
    }
}
