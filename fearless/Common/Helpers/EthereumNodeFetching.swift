import Foundation
import SSFModels
import Web3
import FearlessKeys

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

    func blastProjectIdInjectedURL(baseURL: URL) -> URL {
        switch self {
        case .ethereumMainnet:
            let apiKey = BlastProjectIds.ethereumProjectId
            return baseURL.appendingPathComponent(apiKey)
        case .sepolia:
            let apiKey = BlastProjectIds.sepoliaGoerliProjectId
            return baseURL.appendingPathComponent(apiKey)
        case .goerli:
            let apiKey = BlastProjectIds.sepoliaGoerliProjectId
            return baseURL.appendingPathComponent(apiKey)
        case .bscMainnet, .bscTestnet:
            let apiKey = BlastProjectIds.bscProjectId
            return baseURL.appendingPathComponent(apiKey)
        case .polygon:
            let apiKey = BlastProjectIds.polygonProjectId
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
        if let https = try? getHttps(for: chain) {
            return https
        }

        let randomWssNode = chain.nodes.filter { $0.url.absoluteString.contains("wss") }.randomElement()
        let hasSelectedWssNode = chain.selectedNode?.url.absoluteString.contains("wss") == true
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
        let randomWssNode = chain.nodes.filter { $0.url.absoluteString.contains("https") }.randomElement()
        let hasSelectedWssNode = chain.selectedNode?.url.absoluteString.contains("https") == true
        let node = hasSelectedWssNode ? chain.selectedNode : randomWssNode

        guard var httpsURL = node?.url else {
            throw ConvenienceError(error: "cannot obtain eth https url for chain: \(chain.name)")
        }

        if httpsURL.absoluteString.contains("blastapi"), let ethereumChain = EthereumChain(rawValue: chain.chainId) {
            httpsURL = ethereumChain.blastProjectIdInjectedURL(baseURL: httpsURL)
        }

        return Web3(rpcURL: httpsURL.absoluteString).eth
    }
}
