import Foundation
import SSFModels
import SSFUtils

typealias ChainConnection = JSONRPCEngine

// The SDK retains its retry count across URL rotations. Bound the delay so a
// temporary outage of every node cannot postpone recovery indefinitely.
struct ChainReconnectionStrategy: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt: Int) -> TimeInterval? {
        min(30, ExponentialReconnection().reconnectAfter(attempt: max(0, attempt)) ?? 30)
    }
}

final class FailoverChainConnection: JSONRPCEngine, WebSocketEngineDelegate {
    private let urls: [URL]
    private let logger: SDKLoggerProtocol
    private let processingQueue: DispatchQueue
    private let reconnectionStrategy: ReconnectionStrategyProtocol
    private let engineFactory: ((String?, URL) -> WebSocketEngine)?
    private weak var externalDelegate: WebSocketEngineDelegate?

    private var currentConnection: WebSocketEngine?
    private var failedUrls: Set<URL> = []

    var connectionName: String? {
        get { currentConnection?.connectionName }
        set { currentConnection?.connectionName = newValue }
    }

    var url: URL? {
        get { currentConnection?.url }
        set {
            guard let newValue else {
                return
            }

            if let currentConnection {
                currentConnection.reconnect(url: newValue)
            } else {
                currentConnection = makeConnection(connectionName: connectionName, url: newValue)
            }
        }
    }

    var pendingEngineRequests: [JSONRPCRequest] {
        currentConnection?.pendingEngineRequests ?? []
    }

    init(
        connectionName: String?,
        urls: [URL],
        delegate: WebSocketEngineDelegate,
        processingQueue: DispatchQueue,
        logger: SDKLoggerProtocol,
        reconnectionStrategy: ReconnectionStrategyProtocol = ChainReconnectionStrategy(),
        engineFactory: ((String?, URL) -> WebSocketEngine)? = nil
    ) throws {
        guard !urls.isEmpty else {
            throw ConnectionPoolError.noConnection
        }

        self.urls = urls
        externalDelegate = delegate
        self.processingQueue = processingQueue
        self.logger = logger
        self.reconnectionStrategy = reconnectionStrategy
        self.engineFactory = engineFactory
        currentConnection = makeConnection(connectionName: connectionName, url: urls[0])
        currentConnection?.connectIfNeeded()
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        try activeConnection().callMethod(method, params: params, options: options, completion: closure)
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        try activeConnection().subscribe(
            method,
            params: params,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        currentConnection?.cancelForIdentifier(identifier)
    }

    func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing) {
        currentConnection?.cancelForIdentifier(identifier, writeAuthorization: writeAuthorization)
    }

    func generateRequestId() -> UInt16 {
        currentConnection?.generateRequestId() ?? 0
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        currentConnection?.addSubscription(subscription)
    }

    func reconnect(url: URL) {
        if let currentConnection {
            currentConnection.reconnect(url: url)
        } else {
            currentConnection = makeConnection(connectionName: connectionName, url: url)
        }
    }

    func connectIfNeeded() {
        currentConnection?.connectIfNeeded()
    }

    func disconnectIfNeeded() {
        currentConnection?.disconnectIfNeeded()
    }

    func unsubsribe(_ identifier: UInt16) throws {
        try activeConnection().unsubsribe(identifier)
    }

    func webSocketDidChangeState(
        engine: WebSocketEngine,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        externalDelegate?.webSocketDidChangeState(engine: engine, from: oldState, to: newState)

        guard let previousUrl = engine.url else {
            return
        }

        switch newState {
        case .connected:
            failedUrls.removeAll()
        case let .waitingReconnection(attempt: attempt):
            if attempt > NetworkConstants.websocketReconnectAttemptsLimit {
                rotateConnection(ignoring: previousUrl)
            }
        default:
            break
        }
    }
}

private extension FailoverChainConnection {
    func activeConnection() throws -> WebSocketEngine {
        if let currentConnection {
            return currentConnection
        }

        guard let nextUrl = nextAvailableURL(ignoring: nil) else {
            throw ConnectionPoolError.noConnection
        }

        let connection = makeConnection(connectionName: connectionName, url: nextUrl)
        currentConnection = connection
        return connection
    }

    func makeConnection(connectionName: String?, url: URL) -> WebSocketEngine {
        let engine = engineFactory?(connectionName, url) ?? WebSocketEngine(
            connectionName: connectionName,
            url: url,
            reconnectionStrategy: reconnectionStrategy,
            processingQueue: processingQueue,
            autoconnect: false,
            logger: logger
        )
        engine.delegate = self
        return engine
    }

    func nextAvailableURL(ignoring ignoredURL: URL?) -> URL? {
        urls.first { url in
            url != ignoredURL && !failedUrls.contains(url)
        }
    }

    func rotateConnection(ignoring ignoredURL: URL?) {
        if let ignoredURL {
            failedUrls.insert(ignoredURL)
        }

        if nextAvailableURL(ignoring: ignoredURL) == nil {
            // Failed nodes may recover. Start another cycle instead of leaving
            // every earlier candidate permanently excluded after an outage.
            failedUrls.removeAll()
        }
        guard let nextURL = nextAvailableURL(ignoring: ignoredURL) else {
            return
        }

        // Retain RPC bookkeeping so pending reads and subscriptions survive;
        // reconnect creates and starts a fresh transport for the new endpoint.
        if let currentConnection {
            currentConnection.reconnect(url: nextURL)
        } else {
            currentConnection = makeConnection(connectionName: connectionName, url: nextURL)
        }
    }
}

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
        try FailoverChainConnection(
            connectionName: connectionName,
            urls: urls,
            delegate: delegate,
            processingQueue: processingQueue,
            logger: logger
        )
    }
}
