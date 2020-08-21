import XCTest
@testable import fearless
import RobinHood
import IrohaCrypto

class NetworkItemMapperTests: XCTestCase {

    func testSaveAndFetchItem() throws {
        // given

        let operationQueue = OperationQueue()

        let repository: CoreDataRepository<ConnectionItem, CDConnectionItem> =
            UserDataStorageTestFacade.shared.createRepository()

        // when

        let sortBlock = { (c1: ConnectionItem, c2: ConnectionItem) -> Bool in
            c1.type < c2.type
        }

        let connections = ConnectionItem.supportedConnections

        let saveOperation = repository.saveOperation({ connections }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        // then

        XCTAssertNoThrow(try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))

        let receivedConnections = try fetchOperation.extractResultData()

        XCTAssertEqual(connections.sorted(by: sortBlock), receivedConnections?.sorted(by: sortBlock))
    }

}
