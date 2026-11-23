import Foundation

/// Address and signing family of a chain.
public enum Ecosystem: String, Codable, Sendable, CaseIterable, Hashable {
    case substrate
    case evm

    public var displayName: String {
        switch self {
        case .substrate: return "Polkadot ecosystem"
        case .evm: return "Ethereum & EVM"
        }
    }
}

/// Block explorer links for a chain. Templates contain `{hash}` or `{address}`.
public struct Explorer: Hashable, Codable, Sendable {
    public var name: String
    public var transactionURLTemplate: String?
    public var accountURLTemplate: String?

    public init(name: String, transactionURLTemplate: String?, accountURLTemplate: String?) {
        self.name = name
        self.transactionURLTemplate = transactionURLTemplate
        self.accountURLTemplate = accountURLTemplate
    }

    public func transactionURL(hash: String) -> URL? {
        guard let template = transactionURLTemplate,
              let encoded = hash.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return nil }
        return URL(string: template.replacingOccurrences(of: "{hash}", with: encoded))
    }

    public func accountURL(address: String) -> URL? {
        guard let template = accountURLTemplate,
              let encoded = address.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return nil }
        return URL(string: template.replacingOccurrences(of: "{address}", with: encoded))
    }
}

public struct Chain: Identifiable, Hashable, Codable, Sendable {
    public var id: ChainID
    public var name: String
    public var ecosystem: Ecosystem
    public var isTestnet: Bool
    /// SS58 address prefix (Substrate chains only).
    public var ss58Prefix: UInt16?
    /// EIP-155 chain id (EVM chains only).
    public var evmChainID: UInt64?
    public var nativeAssetID: AssetID
    public var explorer: Explorer?
    /// File stem of the chain icon in the repository's
    /// `remote-config/production/icons/chains/white/` folder (e.g. `"Polkadot"`).
    public var iconName: String?
    /// Brand colour as `#RRGGBB`, used for icon discs and charts.
    public var accentHex: String?
    /// Catalog order; lower first.
    public var sortOrder: Int

    public init(
        id: ChainID,
        name: String,
        ecosystem: Ecosystem,
        isTestnet: Bool,
        ss58Prefix: UInt16? = nil,
        evmChainID: UInt64? = nil,
        nativeAssetID: AssetID,
        explorer: Explorer? = nil,
        iconName: String? = nil,
        accentHex: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.ecosystem = ecosystem
        self.isTestnet = isTestnet
        self.ss58Prefix = ss58Prefix
        self.evmChainID = evmChainID
        self.nativeAssetID = nativeAssetID
        self.explorer = explorer
        self.iconName = iconName
        self.accentHex = accentHex
        self.sortOrder = sortOrder
    }
}

public enum AssetKind: Hashable, Codable, Sendable {
    case native
    case erc20(contract: String)
    case substrateAsset(id: String)
}

public struct Asset: Identifiable, Hashable, Codable, Sendable {
    public var id: AssetID
    public var symbol: String
    public var name: String
    public var decimals: Int
    public var kind: AssetKind
    /// CoinGecko-style price id (e.g. `"polkadot"`); nil when no price feed.
    public var priceID: String?
    /// Minimum balance an account must keep (Substrate existential deposit).
    public var existentialDeposit: TokenAmount?
    /// Icon file stem in `remote-config/production/icons/chains/white/`, if any.
    public var iconName: String?
    /// True for stablecoins and other assets shown with fiat-like precision.
    public var isStablecoin: Bool

    public init(
        id: AssetID,
        symbol: String,
        name: String,
        decimals: Int,
        kind: AssetKind,
        priceID: String? = nil,
        existentialDeposit: TokenAmount? = nil,
        iconName: String? = nil,
        isStablecoin: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.kind = kind
        self.priceID = priceID
        self.existentialDeposit = existentialDeposit
        self.iconName = iconName
        self.isStablecoin = isStablecoin
    }

    public var chainID: ChainID { id.chainID }
}

/// An RPC endpoint of a chain.
public struct ChainNode: Identifiable, Hashable, Codable, Sendable {
    public var id: String { url.absoluteString }
    public var name: String
    public var url: URL
    public var isCustom: Bool

    public init(name: String, url: URL, isCustom: Bool) {
        self.name = name
        self.url = url
        self.isCustom = isCustom
    }
}
