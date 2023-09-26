import Foundation
import SSFModels
import Web3

protocol EthereumConnectionPoolProtocol {
    associatedtype T

    func setup(with chains: [ChainModel]) throws
    func setupConnection(for chain: ChainModel) -> T
    func getConnection(for chainId: ChainModel.Id) -> T
}

final class EthereumConnectionPool: ConnectionPoolProtocol {
    typealias T = Web3.Eth

    private(set) var connectionsByChainIds: [ChainModel.Id: Web3.Eth] = [:]
    private weak var delegate: ConnectionPoolDelegate?

    func setupConnection(for chain: SSFModels.ChainModel) throws -> Web3.Eth {
        let ws = try EthereumNodeFetching().getNode(for: chain)
        connectionsByChainIds[chain.chainId] = ws

        return ws
    }

    func setupConnection(for chain: SSFModels.ChainModel, ignoredUrl _: URL?) throws -> Web3.Eth {
        // TODO: Ignored URL handling
        let ws = try EthereumNodeFetching().getNode(for: chain)
        connectionsByChainIds[chain.chainId] = ws

        return ws
    }

    func getConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        connectionsByChainIds[chainId]
    }

    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func resetConnection(for chainId: ChainModel.Id) {
        connectionsByChainIds = connectionsByChainIds.filter { $0.key != chainId }
    }
}
