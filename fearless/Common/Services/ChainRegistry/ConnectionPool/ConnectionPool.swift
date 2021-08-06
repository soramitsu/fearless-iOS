import Foundation

protocol ConnectionPoolProtocol {
    func getConnection(for chain: ChainModel) throws -> JSONRPCEngine
    func getConnectionStates() throws -> [ConnectionPoolState]
}

class ConnectionPool {
    let logger: LoggerProtocol

    private var mutex = NSLock()

    private var connections: [ChainModel.Id: WeakWrapper] = [:]

    private func clearUnusedConnections() {
        connections = connections.filter { $0.value.target != nil }
    }

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension ConnectionPool: ConnectionPoolProtocol {
    func getConnection(for chain: ChainModel) throws -> JSONRPCEngine {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        if let connection = connections[chain.chainId]?.target as? JSONRPCEngine {
            return connection
        }

        let connection = try WebSocketEngine.createFrom(chain: chain, logger: logger)
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
            guard let connection = weakWrapper.target as? WebSocketEngine else {
                return nil
            }

            return ConnectionPoolState(chainId: chainId, state: connection.state)
        }

        return states
    }
}
