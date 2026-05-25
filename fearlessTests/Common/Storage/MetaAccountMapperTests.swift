import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData

class MetaAccountMapperTests: XCTestCase {
    func testSaveAndFetch() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let maxChainAccountCount = 3
        let accountCount = 10

        let metaAccounts: [fearless.ManagedMetaAccountModel] = (0..<accountCount).map { _ in
            let account = AccountGenerator.generateMetaAccount(
                generatingChainAccounts: (0..<maxChainAccountCount).randomElement()!
            )

            return fearless.ManagedMetaAccountModel(
                info: account,
                isSelected: false,
                order: fearless.ManagedMetaAccountModel.noOrder
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

    func testCodableCoreDataMapper_whenSavingMetaAccount_thenRoundTrips() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let mapper = CodableCoreDataMapper<MetaAccountModel, CDMetaAccount>(
            entityIdentifierFieldName: #keyPath(CDMetaAccount.metaId)
        )
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let metaAccount = AccountGenerator.generateMetaAccount(generatingChainAccounts: 2)

        let saveOperation = repository.saveOperation({ [metaAccount] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        XCTAssertNoThrow(
            try saveOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        let fetchedAccounts = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(fetchedAccounts, [metaAccount])
    }

}
