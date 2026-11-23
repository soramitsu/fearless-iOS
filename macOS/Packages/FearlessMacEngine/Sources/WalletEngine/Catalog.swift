import Foundation
import WalletCore

struct Catalog: ChainCatalogServicing {
    struct Token: Decodable {
        let key, name, symbol: String
        let decimals: Int
        let priceID, minimum: String?
    }

    struct History: Decodable { let type, url: String }
    struct SigningPins: Decodable {
        let balances, keepAlive, allowDeath: UInt8
        let assets, assetKeepAlive: UInt8?
        let extensions: [String]
    }

    struct Network: Decodable {
        let id: ChainID
        let name, icon, accent: String
        let prefix: UInt16?
        let evmID: UInt64?
        let signing: SigningPins?
        let testnet: Bool
        let assets: [Token]
        let nodes: [ChainNode]
        let history: History?
        let explorer: Explorer?
    }

    /// Tokens with a coloured icon in `remote-config/production/icons/tokens/coloured/`.
    static let colouredTokenIcons: Set<String> = ["DOT", "KSM", "WND", "ETH", "BNB", "POL", "USDT", "USDC"]

    static let networks: [Network] = {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Network].self, from: data) else { return [] }
        return records
    }()

    static func chain(_ id: ChainID) throws -> Network {
        guard let chain = networks.first(where: { $0.id == id }) else { throw WalletError.unsupportedChain }
        return chain
    }

    func chains() async -> [Chain] {
        Self.networks.enumerated().map { order, network in
            Chain(
                id: network.id,
                name: network.name,
                ecosystem: network.evmID == nil ? .substrate : .evm,
                isTestnet: network.testnet,
                ss58Prefix: network.prefix,
                evmChainID: network.evmID,
                nativeAssetID: .native(network.id),
                explorer: network.explorer,
                iconName: network.icon,
                accentHex: network.accent,
                sortOrder: order
            )
        }
    }

    func assets() async -> [Asset] {
        Self.networks.flatMap { network in network.assets.map { token in
            let id = AssetID(chainID: network.id, key: token.key)
            let kind: AssetKind = id.isNative ? .native : token.key.hasPrefix("asset:") ?
                .substrateAsset(id: String(token.key.dropFirst(6))) : .erc20(contract: String(token.key.dropFirst(6)))
            return Asset(
                id: id,
                symbol: token.symbol,
                name: token.name,
                decimals: token.decimals,
                kind: kind,
                priceID: token.priceID,
                existentialDeposit: token.minimum.flatMap { TokenAmount(units: $0, decimals: token.decimals) },
                iconName: id.isNative ? network.icon : nil,
                isStablecoin: !id.isNative,
                tokenIconName: Self.colouredTokenIcons.contains(token.symbol) ? token.symbol : nil
            )
        } }
    }
}
