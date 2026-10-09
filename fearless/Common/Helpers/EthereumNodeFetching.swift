import Foundation
import SSFModels
import Web3
#if canImport(FearlessKeys)
    import FearlessKeys
#endif

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

    func apiKeyInjectedURL(baseURL: URL) -> URL {
        switch self {
        case .ethereumMainnet:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.ethereumApiKey
            #else
                let apiKey = EthereumNodesApiKeys.ethereumApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .sepolia:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.sepoliaApiKey
            #else
                let apiKey = EthereumNodesApiKeys.sepoliaApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .goerli:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.goerliApiKey
            #else
                let apiKey = EthereumNodesApiKeys.goerliApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .bscMainnet:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.bscApiKey
            #else
                let apiKey = EthereumNodesApiKeys.bscApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .bscTestnet:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.bscApiKey
            #else
                let apiKey = EthereumNodesApiKeys.bscApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .polygon:
            #if canImport(FearlessKeys) && DEBUG
                let apiKey = EthereumNodesApiKeysDebug.polygonApiKey
            #else
                let apiKey = EthereumNodesApiKeys.polygonApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        }
    }

    private func availableNodesUrls() -> [String] {
        switch self {
        case .ethereumMainnet:
            return ["eth-mainnet.blastapi.io"]
        case .sepolia:
            return ["eth-sepolia.blastapi.io"]
        case .goerli:
            return ["eth-goerli.blastapi.io"]
        case .bscMainnet:
            return ["bsc-mainnet.blastapi.io"]
        case .bscTestnet:
            return ["bsc-testnet.blastapi.io"]
        case .polygon:
            return ["polygon-mainnet.blastapi.io"]
        }
    }
}

protocol EthereumNodeFetchingProtocol {
    func getNode(for chain: ChainModel) throws -> Web3.Eth
}

final class EthereumNodeFetching: EthereumNodeFetchingProtocol {
    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        if let https = try? getHttps(for: chain) {
            return https
        }

        let randomWssNode = chain.nodes.filter {
            $0.url.scheme?.lowercased() == "wss"
        }.randomElement()
        let hasSelectedWssNode =
            chain.selectedNode?.url.scheme?.lowercased() == "wss"
        let node = hasSelectedWssNode ? chain.selectedNode : randomWssNode

        guard var wssURL = node?.url else {
            throw ConvenienceError(error: "cannot obtain eth wss url for chain: \(chain.name)")
        }

        if let ethereumChain = EthereumChain(rawValue: chain.chainId) {
            wssURL = ethereumChain.apiKeyInjectedURL(baseURL: wssURL)
        }

        let provider = try Web3WebSocketProvider(wsUrl: wssURL.absoluteString, timeout: .seconds(10))
        let web3 = Web3(provider: provider, rpcId: Int(chain.chainId) ?? 1)
        return web3.eth
    }

    func getHttps(for chain: ChainModel) throws -> Web3.Eth {
        let randomHttpsNode = chain.nodes.filter {
            $0.url.scheme?.lowercased() == "https"
        }.randomElement()
        let hasSelectedHttpsNode =
            chain.selectedNode?.url.scheme?.lowercased() == "https"
        let node = hasSelectedHttpsNode
            ? chain.selectedNode
            : randomHttpsNode

        guard let httpsURL = node?.url else {
            throw ConvenienceError(error: "cannot obtain eth https url for chain: \(chain.name)")
        }

        return Web3(rpcURL: httpsURL.absoluteString).eth
    }
}
