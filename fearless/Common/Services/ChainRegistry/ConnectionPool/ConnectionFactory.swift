import Foundation

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel) throws -> JSONRPCEngine
}

final class ConnectionFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel) throws -> JSONRPCEngine {
        guard let url = chain.nodes.first?.url else {
            throw JSONRPCEngineError.unknownError
        }

        return WebSocketEngine(url: url, logger: logger)
    }
}
