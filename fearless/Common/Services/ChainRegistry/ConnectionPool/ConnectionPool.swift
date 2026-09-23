import Foundation
import SSFUtils
import SoraFoundation
import SSFModels

enum ConnectionPoolError: LocalizedError {
    case onlyOneNode
    case noConnection

    var errorDescription: String? {
        switch self {
        case .onlyOneNode:
            return "No alternative network node is available."
        case .noConnection:
            return "No WebSocket node is available. Select a WS or WSS node in network settings."
        }
    }
}

protocol ConnectionPoolProtocol {
    associatedtype T

    func setupConnection(for chain: ChainModel) throws -> T
    func getConnection(for chainId: ChainModel.Id) -> T?
    func setDelegate(_ delegate: ConnectionPoolDelegate)
    func resetConnection(for chainId: ChainModel.Id)
}

protocol ConnectionPoolDelegate: AnyObject {
    func webSocketDidChangeState(chainId: ChainModel.Id, state: WebSocketEngine.State)
}

final class ConnectionPool {
    struct ConnectionWrapper {
        let chainId: String
        let connection: WeakWrapper
    }

    private let connectionFactory: ConnectionFactoryProtocol
    private let applicationHandler = ApplicationHandler()
    private let injector: NodeApiKeyInjector
    private weak var delegate: ConnectionPoolDelegate?

    private(set) var connections: SafeArray<ConnectionWrapper> = .init()

    init(connectionFactory: ConnectionFactoryProtocol, injector: NodeApiKeyInjector = NodeApiKeyInjector()) {
        self.connectionFactory = connectionFactory
        self.injector = injector
    }

    private func clearUnusedConnections() {
        let filtred = connections.filter { $0.connection.target != nil }
        connections.replace(array: filtred)
    }
}

// MARK: - ConnectionPoolProtocol

extension ConnectionPool: ConnectionPoolProtocol {
    typealias T = ChainConnection

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        if let connection = getConnection(for: chain.chainId) {
            return connection
        }
        // Keep the user's preference first, but retain catalog fallbacks when
        // that endpoint is unavailable. This never rewrites the saved selection.
        let catalogNodes = chain.nodes.sorted {
            ($0.url.absoluteString, $0.name) < ($1.url.absoluteString, $1.name)
        }
        let nodesForPreparing = chain.selectedNode.map { [$0] + catalogNodes } ?? catalogNodes
        var seen: Set<URL> = []
        let preparedUrls = injector.injectKey(nodes: nodesForPreparing).filter { url in
            guard let scheme = url.scheme?.lowercased(), ["ws", "wss"].contains(scheme),
                  let host = url.host, !host.isEmpty
            else {
                return false
            }
            return seen.insert(url).inserted
        }
        guard !preparedUrls.isEmpty else {
            throw ConnectionPoolError.noConnection
        }
        let connection = try connectionFactory.createConnection(
            connectionName: chain.chainId,
            for: preparedUrls,
            delegate: self
        )

        let wrapper = ConnectionWrapper(chainId: chain.chainId, connection: WeakWrapper(target: connection))
        connections.append(wrapper)
        return connection
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        connections.first(where: { $0.chainId == chainId })?.connection.target as? ChainConnection
    }

    func setDelegate(_ delegate: any ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func resetConnection(for chainId: ChainModel.Id) {
        if let connection = getConnection(for: chainId) {
            connection.disconnectIfNeeded()
        }
        connections.remove(where: { $0.chainId == chainId })
    }
}

// MARK: - WebSocketEngineDelegate

extension ConnectionPool: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine: WebSocketEngine,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard let chainId = engine.connectionName else {
            return
        }

        delegate?.webSocketDidChangeState(chainId: chainId, state: newState)
    }
}
