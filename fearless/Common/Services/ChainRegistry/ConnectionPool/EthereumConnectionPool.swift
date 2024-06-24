import Foundation
import SSFModels
import Web3
import SSFUtils

final class EthereumConnectionPool: ConnectionPoolProtocol {
    typealias T = Web3.Eth

    private(set) var connectionsByChainIds: [ChainModel.Id: Web3.Eth] = [:]
    private weak var delegate: ConnectionPoolDelegate?

    private lazy var lock = NSLock()

    func setupConnection(for chain: SSFModels.ChainModel) throws -> Web3.Eth {
        if let connection = connectionsByChainIds[chain.chainId] {
            return connection
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        let ws = try EthereumNodeFetching().getNode(for: chain)
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
        connectionsByChainIds = connectionsByChainIds.filter { $0.key != chainId }
    }
}
