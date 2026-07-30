import Foundation
import SSFModels
import Web3
import SSFUtils

final class EthereumConnectionPool: ConnectionPoolProtocol {
    typealias T = Web3.Eth

    private(set) var connectionsByChainIds: [ChainModel.Id: Web3.Eth] = [:]
    private weak var delegate: ConnectionPoolDelegate?
    private let nodeFetching: EthereumNodeFetchingProtocol

    private lazy var lock = NSLock()

    init(
        nodeFetching: EthereumNodeFetchingProtocol =
            EthereumNodeFetching()
    ) {
        self.nodeFetching = nodeFetching
    }

    func setupConnection(for chain: SSFModels.ChainModel) throws -> Web3.Eth {
        lock.lock()
        defer {
            lock.unlock()
        }

        if let connection = connectionsByChainIds[chain.chainId] {
            return connection
        }

        let ws = try nodeFetching.getNode(for: chain)

        connectionsByChainIds[chain.chainId] = ws

        return ws
    }

    func getConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return connectionsByChainIds[chainId]
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
}
