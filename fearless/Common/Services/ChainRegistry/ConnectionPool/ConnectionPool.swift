import Foundation
import SSFUtils
import SoraFoundation

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
    private let applicationHandler = ApplicationHandler()
    private weak var delegate: ConnectionPoolDelegate?
    private let operationQueue: OperationQueue

    private let mutex = NSLock()
    private lazy var readLock = ReaderWriterLock()

    private(set) var connectionsByChainIds: [ChainModel.Id: WeakWrapper] = [:]
    private var failedUrls: [ChainModel.Id: Set<URL?>] = [:]

    private func clearUnusedConnections() {
        readLock.exclusivelyWrite {
            self.connectionsByChainIds = self.connectionsByChainIds.filter { $0.value.target != nil }
        }
    }

    init(connectionFactory: ConnectionFactoryProtocol, operationQueue: OperationQueue) {
        self.connectionFactory = connectionFactory
        self.operationQueue = operationQueue
        applicationHandler.delegate = self
    }
}

// MARK: - ConnectionPoolProtocol

extension ConnectionPool: ConnectionPoolProtocol {
    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        try setupConnection(for: chain, ignoredUrl: nil)
    }

    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection {
        if ignoredUrl == nil,
           let connection = getConnection(for: chain.chainId),
           connection.url?.absoluteString == chain.selectedNode?.url.absoluteString {
            return connection
        }

        var chainFailedUrls = getFailedUrls(for: chain.chainId).or([])
        let node = chain.selectedNode ?? chain.nodes.first(where: {
            ($0.url != ignoredUrl) && !chainFailedUrls.contains($0.url)
        })
        chainFailedUrls.insert(ignoredUrl)

        readLock.exclusivelyWrite { [weak self] in
            self?.failedUrls[chain.chainId] = chainFailedUrls
        }

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

        readLock.exclusivelyWrite { [weak self] in
            self?.connectionsByChainIds[chain.chainId] = wrapper
        }

        return connection
    }

    func getFailedUrls(for chainId: ChainModel.Id) -> Set<URL?>? {
        readLock.concurrentlyRead { failedUrls[chainId] }
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        readLock.concurrentlyRead { connectionsByChainIds[chainId]?.target as? ChainConnection }
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

// MARK: - ApplicationHandlerDelegate

extension ConnectionPool: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        let operations: [DisconnectOperation] = connectionsByChainIds.values.compactMap { wrapper in
            guard let connection = wrapper.target as? ChainConnection else {
                return nil
            }

            return DisconnectOperation(connection: connection)
        }

        operationQueue.addOperations(operations, waitUntilFinished: true)
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        let operations: [ConnectOperation] = connectionsByChainIds.values.compactMap { wrapper in
            guard let connection = wrapper.target as? ChainConnection else {
                return nil
            }

            return ConnectOperation(connection: connection)
        }

        operationQueue.addOperations(operations, waitUntilFinished: true)
    }
}
