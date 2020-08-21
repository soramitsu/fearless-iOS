import XCTest
@testable import fearless
import RobinHood
import IrohaCrypto

class AccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem() throws {
        // given

        let operationQueue = OperationQueue()

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade.shared.createRepository()

        // when

        let keypair = try SECKeyFactory().createRandomKeypair()
        let address = try SS58AddressFactory().address(fromPublicKey: keypair.publicKey(),
                                                   type: .kusamaMain)

        let accountItem = AccountItem(address: address,
                                      cryptoType: .ecdsa,
                                      username: "myname",
                                      publicKeyData: keypair.publicKey().rawData())

        let saveOperation = repository.saveOperation({ [accountItem] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        // then

        XCTAssertNoThrow(try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))

        let receivedAccountItem = try fetchOperation.extractResultData()

        XCTAssertEqual([accountItem], receivedAccountItem)
    }
}
