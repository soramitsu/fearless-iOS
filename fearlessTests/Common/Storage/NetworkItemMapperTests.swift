import XCTest
@testable import fearless
import RobinHood
import SSFModels

final class NetworkItemMapperTests: XCTestCase {
    func testSaveAndFetchItem_whenChainHasNetworkState_thenPreservesNodesAndMetadata() throws {
        let operationQueue = OperationQueue()
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainModel, CDChain> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )

        let primaryNode = ChainNodeModel(
            url: URL(string: "wss://example.org")!,
            name: "Main",
            apikey: nil
        )
        let explorer = ChainModel.ExternalApiExplorer(
            type: .subscan,
            types: [.extrinsic, .account],
            url: "https://example.org/explorer"
        )
        let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: "1000",
            name: "Asset Hub",
            xcm: nil,
            nodes: [primaryNode],
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://example.org/icon.png"),
            options: nil,
            externalApi: ChainModel.ExternalApiSet(explorers: [explorer]),
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: "kusama"
        )

        let saveOperation = repository.saveOperation({ [chain] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        XCTAssertNoThrow(
            try saveOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let fetchedChains = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let fetched = try XCTUnwrap(fetchedChains.first)

        XCTAssertEqual(fetched.chainId, chain.chainId)
        XCTAssertEqual(fetched.paraId, chain.paraId)
        XCTAssertEqual(fetched.identityChain, chain.identityChain)
        XCTAssertEqual(Set(fetched.nodes.map(\.url)), Set([primaryNode.url]))
        XCTAssertEqual(fetched.nodes.first?.name, primaryNode.name)
        XCTAssertEqual(fetched.externalApi?.explorers, [explorer])
        XCTAssertNil(fetched.customNodes)
        XCTAssertNil(fetched.selectedNode)
    }
}
