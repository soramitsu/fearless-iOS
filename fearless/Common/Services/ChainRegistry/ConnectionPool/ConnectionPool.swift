import Foundation
import SSFUtils
import SoraFoundation
import SSFModels

enum ConnectionPoolError: Error {
    case onlyOneNode
    case noConnection
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
    private lazy var injector = NodeApiKeyInjector()
    private weak var delegate: ConnectionPoolDelegate?

    private(set) var connections: SafeArray<ConnectionWrapper> = .init()

    init(connectionFactory: ConnectionFactoryProtocol) {
        self.connectionFactory = connectionFactory
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
        let nodesForPreparing: [ChainNodeModel]
        if let selectedNode = chain.selectedNode {
            nodesForPreparing = [selectedNode]
        } else {
            nodesForPreparing = Array(chain.nodes)
        }

        let preparedUrls = injector.injectKey(nodes: nodesForPreparing)
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

    func resetConnection(for _: ChainModel.Id) {}
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

struct NodeApiKeyInjector {
    func injectKey(nodes: [ChainNodeModel]) -> [URL] {
        nodes.map {
            guard $0.name.lowercased().contains("dwellir") else {
                return $0.url
            }
            #if DEBUG
                return $0.url
            #else
                let apiKey = DwellirNodeApiKey.dwellirApiKey
                return $0.url.appendingPathComponent("/\(apiKey)")
            #endif
        }
    }
}
