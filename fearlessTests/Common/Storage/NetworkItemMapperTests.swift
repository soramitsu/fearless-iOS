import XCTest
@testable import fearless
import RobinHood
import IrohaCrypto

class NetworkItemMapperTests: XCTestCase {

    func testSaveAndFetchItem() throws {
        // given

        let operationQueue = OperationQueue()

        let mapper = ManagedConnectionItemMapper()

        let repository: CoreDataRepository<ManagedConnectionItem, CDConnectionItem> =
            UserDataStorageTestFacade().createRepository(mapper: AnyCoreDataMapper(mapper))

        // when

        let sortBlock = { (c1: ManagedConnectionItem, c2: ManagedConnectionItem) -> Bool in
            c1.order < c2.order
        }

        let connections = ConnectionItem.supportedConnections.enumerated().map { (index, item) in
            return ManagedConnectionItem(title: item.title,
                                         url: URL(string: item.identifier)!,
                                         type: SNAddressType(rawValue: item.type)!,
                                         order: Int16(index))
        }

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
