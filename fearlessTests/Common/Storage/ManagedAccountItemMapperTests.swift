import XCTest
@testable import fearless
import RobinHood

final class ManagedAccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem_whenManagedAccountStored_thenPreservesSelectionAndOrder() throws {
        let operationQueue = OperationQueue()
        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

        let metaAccount = AccountGenerator.generateMetaAccount().replacingName("metaAccount")
        let accountItem = ManagedMetaAccountModel(
            info: metaAccount,
            isSelected: true,
            order: 1
        )

        let saveOperation = repository.saveOperation({ [accountItem] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        XCTAssertNoThrow(
            try saveOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let receivedAccountItems = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(receivedAccountItems, [accountItem])
    }
}
