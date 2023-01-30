import Foundation
import FearlessUtils

typealias ChainConnection = JSONRPCEngine

protocol ConnectionFactoryProtocol {
    func createConnection(
        connectionName: String?,
        for url: URL,
        delegate: WebSocketEngineDelegate
    ) -> ChainConnection
}

final class ConnectionFactory {
    private let logger: SDKLoggerProtocol
    private lazy var processingQueue: DispatchQueue = {
        DispatchQueue(label: "jp.co.soramitsu.fearless.wallet.ws.processing", qos: .userInitiated)
    }()

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
        let engine = WebSocketEngine(
            connectionName: connectionName,
            url: url,
            processingQueue: processingQueue,
            logger: nil
        )
        engine.delegate = delegate
        return engine
    }
}
