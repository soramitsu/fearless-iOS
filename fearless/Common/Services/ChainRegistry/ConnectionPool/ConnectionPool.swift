import Foundation
import FearlessUtils

enum ConnectionPoolError: Error {
    case onlyOneNode
}

protocol ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> ChainConnection
    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func setDelegate(_ delegate: ConnectionPoolDelegate)
}

protocol ConnectionPoolDelegate: AnyObject {
    func webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
}

final class ConnectionPool {
    private let connectionFactory: ConnectionFactoryProtocol
    private weak var delegate: ConnectionPoolDelegate?

    private let mutex = NSLock()
    private lazy var readLock = ReaderWriterLock()

    private(set) var connectionsByChainIds: [ChainModel.Id: WeakWrapper] = [:]
    private var failedUrls: [ChainModel.Id: Set<URL?>] = [:]

    private func clearUnusedConnections() {
        connectionsByChainIds = connectionsByChainIds.filter { $0.value.target != nil }
    }

    init(connectionFactory: ConnectionFactoryProtocol) {
        self.connectionFactory = connectionFactory
    }
}

extension ConnectionPool: ConnectionPoolProtocol {
    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        try setupConnection(for: chain, ignoredUrl: nil)
    }

    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if ignoredUrl == nil,
           let connection = connectionsByChainIds[chain.chainId]?.target as? ChainConnection,
           connection.url?.absoluteString == chain.selectedNode?.url.absoluteString {
            return connection
        }

        var chainFaledUrls = failedUrls[chain.chainId].or([])
        let node = chain.selectedNode ?? chain.nodes.first(where: {
            ($0.url != ignoredUrl) && !chainFaledUrls.contains($0.url)
        })
        chainFaledUrls.insert(ignoredUrl)
        failedUrls[chain.chainId] = chainFaledUrls

        guard let url = node?.url else {
            throw ConnectionPoolError.onlyOneNode
        }

        clearUnusedConnections()

        if let connection = connectionsByChainIds[chain.chainId]?.target as? ChainConnection {
            if connection.url == url {
                return connection
            } else if ignoredUrl != nil {
                connection.reconnect(url: url)
                return connection
            }
        }

        let connection = connectionFactory.createConnection(
            connectionName: chain.name,
            for: url,
            delegate: self
        )
        let wrapper = WeakWrapper(target: connection)

        connectionsByChainIds[chain.chainId] = wrapper

        return connection
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        readLock.concurrentlyRead { connectionsByChainIds[chainId]?.target as? ChainConnection }
    }
}

extension ConnectionPool: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine: WebSocketEngine,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard let previousUrl = engine.url else {
            return
        }

        delegate?.webSocketDidChangeState(url: previousUrl, state: newState)
    }
}
