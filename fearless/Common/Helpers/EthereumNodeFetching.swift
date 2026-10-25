import Foundation
import SSFModels
import Web3

enum EthereumChain: String {
    case ethereumMainnet = "1"
    case sepolia = "11155111"
    case goerli = "5"
    case bscMainnet = "56"
    case bscTestnet = "97"
    case polygon = "137"

    var alchemyChainIdentifier: String? {
        switch self {
        case .ethereumMainnet:
            return "eth-mainnet"
        case .sepolia:
            return "eth-sepolia"
        case .goerli:
            return "eth-goerli"
        case .bscMainnet:
            return nil
        case .bscTestnet:
            return nil
        case .polygon:
            return "polygon-mainnet"
        }
    }
}

protocol EthereumNodeFetchingProtocol {
    func getNode(for chain: ChainModel) throws -> Web3.Eth
}

enum EthereumNodeFetchingError: LocalizedError, Equatable {
    case noSupportedNode(chainName: String)

    var errorDescription: String? {
        switch self {
        case let .noSupportedNode(chainName):
            return "No supported node is available for \(chainName). Select an HTTPS or WSS node in network settings."
        }
    }
}

enum EthereumNodeSelection {
    static func url(for chain: ChainModel) throws -> URL {
        if let selected = chain.selectedNode?.url, isSupported(selected) {
            return selected
        }

        // Catalog nodes are a Set. A stable HTTPS-first order avoids random
        // provider changes between launches and preserves explicit user choices.
        let candidates = chain.nodes.map(\.url).filter(isSupported).sorted {
            let firstIsHttps = $0.scheme?.lowercased() == "https"
            let secondIsHttps = $1.scheme?.lowercased() == "https"
            if firstIsHttps != secondIsHttps {
                return firstIsHttps
            }
            return $0.absoluteString < $1.absoluteString
        }
        guard let selected = candidates.first else {
            throw EthereumNodeFetchingError.noSupportedNode(chainName: chain.name)
        }
        return selected
    }

    private static func isSupported(_ url: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "wss",
            var host = url.host?.lowercased(),
            !host.isEmpty
        else {
            return false
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        // Blast retired its complete provider service. The DNS boundary matters:
        // do not reject a custom node merely because its path/name mentions it.
        return !host.isEmpty && host != "blastapi.io" && !host.hasSuffix(".blastapi.io")
    }
}

final class EthereumNodeFetching: EthereumNodeFetchingProtocol {
    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        let url = try EthereumNodeSelection.url(for: chain)
        if url.scheme?.lowercased() == "https" {
            return Web3(rpcURL: url.absoluteString).eth
        }

        // Public and custom node URLs may already contain authentication/path
        // components. Preserve them exactly; unrelated provider keys must never
        // be appended or disclosed to these hosts.
        let provider = try Web3WebSocketProvider(wsUrl: url.absoluteString, timeout: .seconds(10))
        return Web3(provider: provider, rpcId: Int(chain.chainId) ?? 1).eth
    }
}
