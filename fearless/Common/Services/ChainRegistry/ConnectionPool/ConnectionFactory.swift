import Foundation
import SSFUtils

typealias ChainConnection = JSONRPCEngine

protocol ConnectionFactoryProtocol {
    func createConnection(
        connectionName: String?,
        for urls: [URL],
        delegate: WebSocketEngineDelegate
    ) throws -> ChainConnection
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
        for urls: [URL],
        delegate: WebSocketEngineDelegate
    ) throws -> ChainConnection {
        guard let connectionStrategy = ConnectionStrategyImpl(
            urls: urls,
            callbackQueue: processingQueue
        ) else {
            throw ConnectionPoolError.noConnection
        }
        let engine = WebSocketEngine(
            connectionName: connectionName,
            connectionStrategy: connectionStrategy
        )
        engine.delegate = delegate
        return engine
    }
}
