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
    /// A connection to `url`, one of the nodes `EthereumNodeSelection` offers for `chain`.
    func getNode(for chain: ChainModel, url: URL) throws -> Web3.Eth
}

extension EthereumNodeFetchingProtocol {
    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        try getNode(for: chain, url: EthereumNodeSelection.url(for: chain))
    }
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
    static func url(for chain: ChainModel, catalogOrder: [URL] = []) throws -> URL {
        if let chosen = chosenURL(for: chain) {
            return chosen
        }

        guard let selected = automaticURLs(for: chain, catalogOrder: catalogOrder).first else {
            throw EthereumNodeFetchingError.noSupportedNode(chainName: chain.name)
        }
        return selected
    }

    /// The node the user chose, exactly as they entered it, when the app can reach it. Automatic selection has none.
    static func chosenURL(for chain: ChainModel) -> URL? {
        guard let selected = chain.selectedNode?.url, isSupported(selected) else {
            return nil
        }
        return selected
    }

    /// The nodes automatic selection goes through: HTTPS nodes before WSS ones, each in the order the chain catalog
    /// lists them (`catalogOrder`), and nodes the catalog order does not know last, by URL. A WSS node is reached over
    /// the same host's HTTPS node when the network lists one, so the socket is used only where no HTTPS node exists.
    static func automaticURLs(for chain: ChainModel, catalogOrder: [URL] = []) -> [URL] {
        let supported = chain.nodes.map(\.url).filter(isSupported)
        let reachable = supported.map { overHTTPS($0, nodes: supported) }
        let ranks = catalogOrder.map { overHTTPS($0, nodes: supported).absoluteString }
            .enumerated()
            .reduce(into: [String: Int]()) { ranks, entry in
                if ranks[entry.element] == nil {
                    ranks[entry.element] = entry.offset
                }
            }

        var seen = Set<String>()
        return reachable
            .filter { seen.insert($0.absoluteString).inserted }
            .sorted {
                let firstIsHttps = isHTTPS($0)
                let secondIsHttps = isHTTPS($1)
                if firstIsHttps != secondIsHttps {
                    return firstIsHttps
                }
                let firstRank = ranks[$0.absoluteString] ?? Int.max
                let secondRank = ranks[$1.absoluteString] ?? Int.max
                if firstRank != secondRank {
                    return firstRank < secondRank
                }
                return $0.absoluteString < $1.absoluteString
            }
    }

    static func isSupported(_ url: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "wss",
            let host = normalizedHost(of: url)
        else {
            return false
        }
        // Blast retired its complete provider service. The DNS boundary matters:
        // do not reject a custom node merely because its path/name mentions it.
        return host != "blastapi.io" && !host.hasSuffix(".blastapi.io")
    }

    private static func isHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    private static func overHTTPS(_ url: URL, nodes: [URL]) -> URL {
        guard !isHTTPS(url) else {
            return url
        }
        return nodes.first { isHTTPS($0) && endpoint(of: $0) == endpoint(of: url) } ?? url
    }

    private static func endpoint(of url: URL) -> String? {
        normalizedHost(of: url).map { "\($0):\(url.port ?? 443)" }
    }

    private static func normalizedHost(of url: URL) -> String? {
        guard var host = url.host?.lowercased() else {
            return nil
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        return host.isEmpty ? nil : host
    }
}

final class EthereumNodeFetching: EthereumNodeFetchingProtocol {
    private let session: URLSession?

    /// - Parameter session: the session HTTPS nodes are reached with; by default each node gets its own.
    init(session: URLSession? = nil) {
        self.session = session
    }

    func getNode(for chain: ChainModel, url: URL) throws -> Web3.Eth {
        guard EthereumNodeSelection.isSupported(url) else {
            throw EthereumNodeFetchingError.noSupportedNode(chainName: chain.name)
        }

        let expectedChainId = EthereumNodeProvider.chainId(fromCatalogId: chain.chainId)
        if url.scheme?.lowercased() == "https" {
            let transport = session.map { Web3HttpProvider(rpcURL: url.absoluteString, session: $0) }
                ?? Web3HttpProvider(rpcURL: url.absoluteString)
            let provider = EthereumNodeProvider(url: url, transport: transport, expectedChainId: expectedChainId)
            return Web3(provider: provider).eth
        }

        // Public and custom node URLs may already contain authentication/path
        // components. Preserve them exactly; unrelated provider keys must never
        // be appended or disclosed to these hosts.
        let transport = try Web3WebSocketProvider(wsUrl: url.absoluteString, timeout: .seconds(10))
        let provider = EthereumBidirectionalNodeProvider(
            url: url,
            transport: transport,
            expectedChainId: expectedChainId
        )
        return Web3(provider: provider, rpcId: Int(chain.chainId) ?? 1).eth
    }
}
