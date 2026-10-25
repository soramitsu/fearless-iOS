import Foundation
import SSFUtils

protocol ConnectionFactoryProtocol {
    func createConnection(
        connectionName: String?,
        for url: URL,
        delegate: WebSocketEngineDelegate
    ) -> SubstrateConnection
}

final class ConnectionFactory: ConnectionFactoryProtocol {
    private lazy var processingQueue: DispatchQueue = .init(
        label: "jp.co.soramitsu.fearless.wallet.ws.SSFChainConnection",
        qos: .userInitiated
    )

    func createConnection(
        connectionName: String?,
        for url: URL,
        delegate: WebSocketEngineDelegate
    ) -> SubstrateConnection {
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
