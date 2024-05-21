import Foundation
import SSFModels
import Web3
import FearlessKeys

enum EthereumNodeFetchingError: Error {
    case unknownChain
}

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
            #if DEBUG
                let apiKey = EthereumNodesApiKeysDebug.ethereumApiKey
            #else
                let apiKey = EthereumNodesApiKeys.ethereumApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .sepolia:
            #if DEBUG
                let apiKey = EthereumNodesApiKeysDebug.sepoliaApiKey
            #else
                let apiKey = EthereumNodesApiKeys.sepoliaApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .goerli:
            #if DEBUG
                let apiKey = EthereumNodesApiKeysDebug.goerliApiKey
            #else
                let apiKey = EthereumNodesApiKeys.goerliApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .bscMainnet:
            #if DEBUG
                let apiKey = EthereumNodesApiKeysDebug.bscApiKey
            #else
                let apiKey = EthereumNodesApiKeys.bscApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .bscTestnet:
            #if DEBUG
                let apiKey = EthereumNodesApiKeysDebug.bscApiKey
            #else
                let apiKey = EthereumNodesApiKeys.bscApiKey
            #endif
            return baseURL.appendingPathComponent(apiKey)
        case .polygon:
            #if DEBUG
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

final class EthereumNodeFetching {
    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        guard let ethereumChain = EthereumChain(rawValue: chain.chainId) else {
            return try getHttps(for: chain)
        }

        let randomWssNode = chain.nodes.filter { $0.url.absoluteString.contains("wss") }.randomElement()
        let hasSelectedWssNode = chain.selectedNode?.url.absoluteString.contains("wss") == true
        let node = hasSelectedWssNode ? chain.selectedNode : randomWssNode

        guard let wssURL = node?.url else {
            return try getHttps(for: chain)
        }

        let finalURL = ethereumChain.apiKeyInjectedURL(baseURL: wssURL)

        let provider = try Web3WebSocketProvider(wsUrl: finalURL.absoluteString, timeout: .seconds(10))
        let web3 = Web3(provider: provider, rpcId: Int(chain.chainId) ?? 1)
        return web3.eth
    }

    func getHttps(for chain: ChainModel) throws -> Web3.Eth {
        let randomWssNode = chain.nodes.filter { $0.url.absoluteString.contains("https") }.randomElement()
        let hasSelectedWssNode = chain.selectedNode?.url.absoluteString.contains("https") == true
        let node = hasSelectedWssNode ? chain.selectedNode : randomWssNode

        guard let httpsURL = node?.url else {
            throw ConvenienceError(error: "cannot obtain eth https url for chain: \(chain.name)")
        }

        return Web3(rpcURL: httpsURL.absoluteString).eth
    }
}
