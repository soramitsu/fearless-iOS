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
        }
    }

    private func availableNodesUrls() -> [String] {
        switch self {
        case .ethereumMainnet:
            return ["eth-mainnet.blastapi.io"]
        case .sepolia:
            return []
        case .goerli:
            return []
        case .bscMainnet:
            return ["bsc-mainnet.blastapi.io"]
        case .bscTestnet:
            return ["bsc-testnet.blastapi.io"]
        }
    }
}

final class EthereumNodeFetching {
    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        guard let ethereumChain = EthereumChain(rawValue: chain.chainId) else {
            throw EthereumNodeFetchingError.unknownChain
        }

        let node = chain.selectedNode?.url.absoluteString.contains("wss") == true ? chain.selectedNode : chain.nodes.filter { $0.url.absoluteString.contains("wss") }.randomElement()

        guard let wssURL = node?.url else {
            throw ConvenienceError(error: "cannot obtain eth rpc url for chain: \(chain.name)")
        }

        let finalURL = ethereumChain.apiKeyInjectedURL(baseURL: wssURL)

        return try Web3(wsUrl: finalURL.absoluteString).eth
    }
}
