import Foundation

protocol ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> JSONRPCEngine
    func getConnectionStates() throws -> [ConnectionPoolState]
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
    func setupConnection(for chain: ChainModel) throws -> JSONRPCEngine {
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

    func getConnectionStates() throws -> [ConnectionPoolState] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        let states: [ConnectionPoolState] = connections.compactMap { chainId, weakWrapper in
            guard let connection = weakWrapper.target as? ConnectionStateReporting else {
                return nil
            }

            return ConnectionPoolState(chainId: chainId, state: connection.state)
        }

        return states
    }
}
