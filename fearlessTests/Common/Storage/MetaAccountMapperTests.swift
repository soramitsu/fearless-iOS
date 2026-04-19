import XCTest
@testable import fearless
import RobinHood
import SSFModels

class MetaAccountMapperTests: XCTestCase {
    func testSaveAndFetch() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let maxChainAccountCount = 3
        let accountCount = 10

        let metaAccounts: [ManagedMetaAccountModel] = (0..<accountCount).map { _ in
            let account = AccountGenerator.generateMetaAccount(
                generatingChainAccounts: (0..<maxChainAccountCount).randomElement()!
            )

            return ManagedMetaAccountModel(
                info: account,
                isSelected: false,
                order: ManagedMetaAccountModel.noOrder
            )
        }

        // when

        let saveOperation = repository.saveOperation( { metaAccounts }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // then

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let expectedAccounts = metaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let differentOrders = allMetaAccounts.reduce(into: Set<UInt32>()) { $0.insert($1.order) }

        XCTAssertEqual(expectedAccounts, actualAccounts)
        XCTAssertEqual(differentOrders.count, accountCount)
    }

    func testAssetModelMapperPersistsIdentifierContract() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = SubstrateStorageTestFacade()
        let mapper = AssetModelMapper()

        let repository: CoreDataRepository<AssetModel, CDAsset> = facade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let asset = ChainModelGenerator.generateAssetWithId("asset-contract-id", symbol: "TST")

        // when

        let saveOperation = repository.saveOperation({ [asset] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        // then

        let fetchedAssets = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(fetchedAssets.count, 1)
        XCTAssertEqual(fetchedAssets.first?.identifier, asset.id)
        XCTAssertEqual(fetchedAssets.first?.id, asset.id)
    }
}
