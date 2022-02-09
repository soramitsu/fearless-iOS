import Foundation
import FearlessUtils

typealias ChainConnection = JSONRPCEngine & ConnectionAutobalancing & ConnectionStateReporting

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel) throws -> ChainConnection
}

final class ConnectionFactory {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel) throws -> ChainConnection {
        guard let url = chain.nodes.first?.url else {
            throw JSONRPCEngineError.unknownError
        }

        return WebSocketEngine(url: url, logger: logger)
    }
}
