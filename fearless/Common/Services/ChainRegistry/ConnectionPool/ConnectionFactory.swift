import Foundation
import FearlessUtils

typealias ChainConnection = JSONRPCEngine & ConnectionAutobalancing & ConnectionStateReporting

protocol ConnectionFactoryProtocol {
    func createConnection(
        connectionName: String?,
        for url: URL,
        delegate: WebSocketEngineDelegate
    ) -> ChainConnection
}

final class ConnectionFactory {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(
        connectionName: String?,
        for url: URL,
        delegate: WebSocketEngineDelegate
    ) -> ChainConnection {
        let engine = WebSocketEngine(connectionName: connectionName, url: url, logger: nil)
        engine.delegate = delegate
        return engine
    }
}
