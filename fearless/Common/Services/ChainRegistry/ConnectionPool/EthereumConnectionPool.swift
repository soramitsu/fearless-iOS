import Foundation
import SSFModels
import Web3
import SSFUtils

final class EthereumConnectionPool: ConnectionPoolProtocol {
    typealias T = Web3.Eth

    private(set) var connectionsByChainIds: [ChainModel.Id: Web3.Eth] = [:]
    /// The automatic node each network moved on to after a node failed. It outlives connection resets, so a rebuilt
    /// connection does not go back to the node that stopped answering.
    private var failoverURLs: [ChainModel.Id: URL] = [:]
    private weak var delegate: ConnectionPoolDelegate?
    private let nodeFetching: EthereumNodeFetchingProtocol
    private let catalogOrder: EthereumNodeCatalogOrderProtocol

    private lazy var lock = NSLock()

    init(
        nodeFetching: EthereumNodeFetchingProtocol =
            EthereumNodeFetching(),
        catalogOrder: EthereumNodeCatalogOrderProtocol = EthereumNodeCatalogOrder.shared
    ) {
        self.nodeFetching = nodeFetching
        self.catalogOrder = catalogOrder
    }

    func setupConnection(for chain: SSFModels.ChainModel) throws -> Web3.Eth {
        lock.lock()
        defer {
            lock.unlock()
        }

        if let connection = connectionsByChainIds[chain.chainId] {
            return connection
        }

        return try connect(chain)
    }

    func getConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return connectionsByChainIds[chainId]
    }

    /// The node the network's connection goes to.
    func currentNodeURL(for chainId: ChainModel.Id) -> URL? {
        getConnection(for: chainId).flatMap(Self.nodeURL(of:))
    }

    /// Replaces `failed`, the connection of a network whose node stopped answering, and returns the connection to retry
    /// on. With automatic selection the network moves on to its next node; a node the user chose is rebuilt in place.
    /// Every request in flight on a dead node fails: the first replaces the connection and the others find it
    /// replaced, so one outage moves the network on once. Returns nothing when no node can be connected.
    func failover(for chain: ChainModel, failed: Web3.Eth) -> Web3.Eth? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let current = connectionsByChainIds[chain.chainId] else {
            // Reset since `failed` was handed out, by a node choice or a catalog update. The network now uses
            // whatever node its settings name, and the failure says nothing about that node.
            return try? connect(chain)
        }

        guard Self.isSameNode(current, failed) else {
            return current
        }

        connectionsByChainIds[chain.chainId] = nil
        return try? connect(chain, after: Self.nodeURL(of: failed))
    }

    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func resetConnection(for chainId: ChainModel.Id) {
        lock.lock()
        defer {
            lock.unlock()
        }

        connectionsByChainIds = connectionsByChainIds.filter { $0.key != chainId }
    }

    // MARK: - Private

    /// Connects the network to the node the user chose, else to an automatic node: the next one after `failedURL`,
    /// else the one the network moved on to, else the first. An automatic node that cannot be connected is skipped.
    private func connect(_ chain: ChainModel, after failedURL: URL? = nil) throws -> Web3.Eth {
        if let chosen = EthereumNodeSelection.chosenURL(for: chain) {
            let connection = try nodeFetching.getNode(for: chain, url: chosen)
            connectionsByChainIds[chain.chainId] = connection
            return connection
        }

        let candidates = EthereumNodeSelection.automaticURLs(
            for: chain,
            catalogOrder: catalogOrder.nodeOrder(for: chain.chainId)
        )
        let start: Int
        if let failedIndex = failedURL.flatMap({ Self.index(of: $0, in: candidates) }) {
            start = failedIndex + 1
        } else {
            start = failoverURLs[chain.chainId].flatMap { Self.index(of: $0, in: candidates) } ?? 0
        }

        var lastError: Error = EthereumNodeFetchingError.noSupportedNode(chainName: chain.name)
        for offset in candidates.indices {
            let url = candidates[(start + offset) % candidates.count]
            do {
                let connection = try nodeFetching.getNode(for: chain, url: url)
                connectionsByChainIds[chain.chainId] = connection
                if failedURL != nil || offset > 0 {
                    failoverURLs[chain.chainId] = url
                }
                return connection
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func index(of url: URL, in urls: [URL]) -> Int? {
        urls.firstIndex { $0.absoluteString == url.absoluteString }
    }

    private static func isSameNode(_ lhs: Web3.Eth, _ rhs: Web3.Eth) -> Bool {
        guard
            let lhsProvider = lhs.properties.provider as? EthereumNodeProvider,
            let rhsProvider = rhs.properties.provider as? EthereumNodeProvider
        else {
            return false
        }
        return lhsProvider === rhsProvider
    }

    private static func nodeURL(of connection: Web3.Eth) -> URL? {
        (connection.properties.provider as? EthereumNodeProvider)?.url
    }
}
