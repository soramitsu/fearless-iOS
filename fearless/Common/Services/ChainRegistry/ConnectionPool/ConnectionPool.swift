import Foundation

protocol ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> ChainConnection
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
}

class ConnectionPool {
    let connectionFactory: ConnectionFactoryProtocol

    private var mutex = NSLock()

    private(set) var connections: [ChainModel.Id: WeakWrapper] = [:]

    private func clearUnusedConnections() {
        connections = connections.filter { $0.value.target != nil }
    }

    init(connectionFactory: ConnectionFactoryProtocol) {
        self.connectionFactory = connectionFactory
    }
}

extension ConnectionPool: ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        if let connection = connections[chain.chainId]?.target as? ChainConnection {
            let ranking = chain.nodes.map { ConnectionRank(chainNode: $0) }
            connection.set(ranking: ranking)
            return connection
        }

        let connection = try connectionFactory.createConnection(for: chain)
        connections[chain.chainId] = WeakWrapper(target: connection)

        return connection
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connections[chainId]?.target as? ChainConnection
    }
}
