import Foundation
import SSFUtils
import SoraFoundation
import SSFModels

enum ConnectionPoolError: Error {
    case onlyOneNode
}

protocol ConnectionPoolProtocol {
    associatedtype T

    func setupConnection(for chain: ChainModel) throws -> T
    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> T
    func getConnection(for chainId: ChainModel.Id) -> T?
    func setDelegate(_ delegate: ConnectionPoolDelegate)
    func resetConnection(for chainId: ChainModel.Id)
}

protocol ConnectionPoolDelegate: AnyObject {
    func webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
}

final class ConnectionPool {
    private let connectionFactory: ConnectionFactoryProtocol
    private let applicationHandler = ApplicationHandler()
    private weak var delegate: ConnectionPoolDelegate?
    private let operationQueue: OperationQueue

    private lazy var lock = ReaderWriterLock()
    private lazy var connectionLock = ReaderWriterLock()

    private(set) var connectionsByChainIds: [ChainModel.Id: WeakWrapper] = [:]
    private var failedUrls: [ChainModel.Id: Set<URL?>] = [:]

    private func clearUnusedConnections() {
        connectionLock.exclusivelyWrite {
            self.connectionsByChainIds = self.connectionsByChainIds.filter { $0.value.target != nil }
        }
    }

    init(connectionFactory: ConnectionFactoryProtocol, operationQueue: OperationQueue) {
        self.connectionFactory = connectionFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - ConnectionPoolProtocol

extension ConnectionPool: ConnectionPoolProtocol {
    typealias T = ChainConnection

    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        try setupConnection(for: chain, ignoredUrl: nil)
    }

    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection {
        if ignoredUrl == nil,
           let connection = getConnection(for: chain.chainId) {
            return connection
        }

        var chainFailedUrls = getFailedUrls(for: chain.chainId).or([])
        let node = chain.selectedNode ?? chain.nodes
            .first(where: {
                ($0.url != ignoredUrl) && !chainFailedUrls.contains($0.url)
            })
        chainFailedUrls.insert(ignoredUrl)

        lock.exclusivelyWrite { [weak self] in
            self?.failedUrls[chain.chainId] = chainFailedUrls
        }

        guard let url = node?.url else {
            throw ConnectionPoolError.onlyOneNode
        }

        clearUnusedConnections()

        if let connection = getConnection(for: chain.chainId) {
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

        connectionLock.exclusivelyWrite { [weak self] in
            self?.connectionsByChainIds[chain.chainId] = wrapper
        }

        return connection
    }

    func getFailedUrls(for chainId: ChainModel.Id) -> Set<URL?>? {
        lock.concurrentlyRead { failedUrls[chainId] }
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        connectionLock.concurrentlyRead { connectionsByChainIds[chainId]?.target as? ChainConnection }
    }

    func resetConnection(for chainId: ChainModel.Id) {
        if let connection = getConnection(for: chainId) {
            connection.disconnectIfNeeded()
        }

        connectionLock.exclusivelyWrite {
            self.connectionsByChainIds = self.connectionsByChainIds.filter { $0.key != chainId }
        }
    }
}

// MARK: - WebSocketEngineDelegate

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
