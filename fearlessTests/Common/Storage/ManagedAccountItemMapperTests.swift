import XCTest
@testable import fearless
import RobinHood
import IrohaCrypto

class ManagedAccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem() throws {
        // given

        let operationQueue = OperationQueue()

        let repository = AccountRepositoryFactory.createManagedRepository(for: UserDataStorageTestFacade())

        // when

        let keypair = try SECKeyFactory().createRandomKeypair()
        let address = try SS58AddressFactory().address(fromPublicKey: keypair.publicKey(),
                                                   type: .kusamaMain)

        let accountItem = ManagedAccountItem(address: address,
                                             cryptoType: .ecdsa,
                                             networkType: .kusamaMain,
                                             username: "fearless",
                                             publicKeyData: keypair.publicKey().rawData(),
                                             order: 1)

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
