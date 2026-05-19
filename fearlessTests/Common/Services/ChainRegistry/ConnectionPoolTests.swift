import XCTest
@testable import fearless
import Cuckoo
import SSFUtils

class ConnectionPoolTests: XCTestCase {
    func testSetupCreatesNewConnections() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            stub(connectionFactory) { stub in
                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
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

            let actualChainIds = Set(connectionPool.connections.map { $0.chainId })
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(connections.count, expectedChainIds.count)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testEthereumConnectionPoolResetRemovesConnectionForChainId() throws {
        let chainId = "e2e-eth-test-chain"
        let chain = makeEthereumLikeChain(chainId: chainId)
        let pool = EthereumConnectionPool()

        _ = try pool.setupConnection(for: chain)

        XCTAssertNotNil(pool.getConnection(for: chainId))

        pool.resetConnection(for: chainId)

        XCTAssertNil(pool.getConnection(for: chainId))
    }

    private func makeEthereumLikeChain(chainId: String) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://rpc.unit.test")!,
            name: "Unit Test ETH Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Unit ETH",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

//    func testSetupUpdatesExistingConnection() {
//        do {
//            // given
//
//            let connectionFactory = MockConnectionFactoryProtocol()
//
//            let setupConnection: () -> MockConnection = {
//                let mockConnection = MockConnection()
//                stub(mockConnection.autobalancing) { stub in
//                    stub.set(ranking: any()).thenDoNothing()
//                    stub.url.get.then { URL(string: "https://github.com") }
//                }
//
//                return mockConnection
//            }
//
//            stub(connectionFactory) { stub in
//                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
//                    setupConnection()
//                }
//            }
//
//            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)
//
//            // when
//
//            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)
//
//            let newConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//            
//            let updatedConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//
//            // then
//
//            let actualChainIds = Set(connectionPool.connectionsByChainIds.keys)
//            let expectedChainIds = Set(chainModels.map { $0.chainId })
//
//            XCTAssertEqual(expectedChainIds, actualChainIds)
//            XCTAssertEqual(newConnections.count, updatedConnections.count)
//
//            for index in 0..<newConnections.count {
//                XCTAssertTrue(newConnections[index] === updatedConnections[index])
//                verify(newConnections[index].autobalancing, times(1)).set(ranking: any())
//            }
//        } catch {
//            XCTFail("Did receive error \(error)")
//        }
//    }
}
