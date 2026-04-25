import XCTest
@testable import fearless
import RobinHood
import SSFModels

final class ChainModelMapperTests: XCTestCase {
    func testSaveAndFetchPreservesParaIdAndIdentityChain() throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainModel, CDChain> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )

        let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: "1000",
            name: "Asset Hub",
            xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://example.org")!, name: "Main", apikey: nil)],
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://example.org/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: "kusama"
        )

        let queue = OperationQueue()

        let saveOperation = repository.saveOperation({ [chain] }, { [] })
        queue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetchOperation], waitUntilFinished: true)

        let fetchedChains = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let fetched = try XCTUnwrap(fetchedChains.first(where: { $0.chainId == chain.chainId }))

        XCTAssertEqual(fetched.paraId, chain.paraId)
        XCTAssertEqual(fetched.identityChain, chain.identityChain)
    }
}
