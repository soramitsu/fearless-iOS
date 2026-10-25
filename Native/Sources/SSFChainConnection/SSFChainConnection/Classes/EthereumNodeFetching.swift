import Foundation
import SSFModels
import Web3

protocol EthereumNodeFetching {
    func getNode(for chain: ChainModel) throws -> Web3.Eth
}

final class EthereumNodeFetchingDefault: EthereumNodeFetching {
    enum UrlScheme: String {
        case wss
        case https
    }

    // MARK: - EthereumNodeFetching

    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        guard let node = getNodeFor(chain: chain, scheme: .wss),
              let apikey = node.apikey?.queryName else
        {
            return try getHttps(for: chain)
        }

        let finalURL = node.url.appendingPathComponent(apikey)

        return try Web3(wsUrl: finalURL.absoluteString).eth
    }

    // MARK: - Private methods

    private func getHttps(for chain: ChainModel) throws -> Web3.Eth {
        guard let httpsURL = getNodeFor(chain: chain, scheme: .https)?.url else {
            throw ConnectionPoolError.connectionFetchingError
        }

        return Web3(rpcURL: httpsURL.absoluteString).eth
    }

    private func getNodeFor(chain: ChainModel, scheme: UrlScheme) -> ChainNodeModel? {
        let randomNode = chain.nodes.filter { $0.url.absoluteString.contains(scheme.rawValue) }
            .randomElement()
        let hasSelectedNode = chain.selectedNode?.url.absoluteString
            .contains(scheme.rawValue) == true
        let node = hasSelectedNode ? chain.selectedNode : randomNode
        return node
    }
}
