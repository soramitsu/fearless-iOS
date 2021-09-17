import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils

class ConnectionPoolTests: XCTestCase {
    func testSetupCreatesNewConnections() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            stub(connectionFactory) { stub in
                stub.createConnection(for: any()).then { _ in
                    MockConnection()
                }
            }

            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let connections: [JSONRPCEngine] = try chainModels.reduce([]) { (allConnections, chain) in
                let connection = try connectionPool.setupConnection(for: chain)
                return allConnections + [connection]
            }

            // then

            let actualChainIds = Set(connectionPool.connections.keys)
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(connections.count, expectedChainIds.count)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testSetupUpdatesExistingConnection() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            let setupConnection: () -> MockConnection = {
                let mockConnection = MockConnection()
                stub(mockConnection.autobalancing) { stub in
                    stub.set(ranking: any()).thenDoNothing()
                }

                return mockConnection
            }

            stub(connectionFactory) { stub in
                stub.createConnection(for: any()).then { _ in
                    setupConnection()
                }
            }

            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let newConnections: [MockConnection] = try chainModels.reduce(
                []
            ) { (allConnections, chain) in
                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
                    return allConnections + [connection]
                } else {
                    return allConnections
                }
            }
            
            let updatedConnections: [MockConnection] = try chainModels.reduce(
                []
            ) { (allConnections, chain) in
                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
                    return allConnections + [connection]
                } else {
                    return allConnections
                }
            }

            // then

            let actualChainIds = Set(connectionPool.connections.keys)
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(newConnections.count, updatedConnections.count)

            for index in 0..<newConnections.count {
                XCTAssertTrue(newConnections[index] === updatedConnections[index])
                verify(newConnections[index].autobalancing, times(1)).set(ranking: any())
            }
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }
}
