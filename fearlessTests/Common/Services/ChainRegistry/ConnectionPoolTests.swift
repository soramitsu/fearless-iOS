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

    func testSetupConnection_whenChainAlreadyHasConnection_thenReusesCachedConnection() throws {
        let connectionFactory = RetainingConnectionFactorySpy()
        let connectionPool = ConnectionPool(connectionFactory: connectionFactory)
        let chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)

        let firstConnection = try connectionPool.setupConnection(for: chain)
        let secondConnection = try connectionPool.setupConnection(for: chain)

        XCTAssertTrue((firstConnection as AnyObject) === (secondConnection as AnyObject))
        XCTAssertEqual(connectionFactory.createConnectionCallCount, 1)
        XCTAssertEqual(connectionPool.connections.count, 1)
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

}

private final class RetainingConnectionFactorySpy: ConnectionFactoryProtocol {
    private var retainedConnections: [ChainConnection] = []
    private(set) var createConnectionCallCount = 0

    func createConnection(
        connectionName: String?,
        for urls: [URL],
        delegate _: WebSocketEngineDelegate
    ) throws -> ChainConnection {
        createConnectionCallCount += 1

        let connection = MockConnection()
        connection.connectionName = connectionName
        connection.url = urls.first
        retainedConnections.append(connection)
        return connection
    }
}
