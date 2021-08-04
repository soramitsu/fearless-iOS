import Foundation

protocol ConnectionPoolProtocol {
    func getConnection(for chain: ChainModel) throws -> JSONRPCEngine
    func getConnectionsState() throws -> [ConnectionPoolState]
}

class ConnectionPool {
    let logger: LoggerProtocol

    private var mutex: NSLock = NSLock()

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

    func getConnectionsState() throws -> [ConnectionPoolState] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        let states = connections.compactMap { (chainId, weakWrapper) in
            
        }
    }
}
