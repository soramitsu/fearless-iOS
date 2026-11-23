import Foundation

/// Stable identifier of a wallet stored on this Mac.
public struct WalletID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

/// Opaque chain identifier chosen by the engine's chain catalog
/// (for Substrate chains the genesis hash in lowercase hex without `0x`,
/// for EVM chains `eip155:<chain id>`). The UI must treat it as opaque.
public struct ChainID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// Identifies one asset on one chain. `key` is `"native"` for the chain's
/// native token, `"erc20:<checksummed contract>"` for ERC-20 tokens and
/// `"asset:<id>"` for Substrate `assets` pallet tokens.
public struct AssetID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let chainID: ChainID
    public let key: String

    public init(chainID: ChainID, key: String) {
        self.chainID = chainID
        self.key = key
    }

    public static func native(_ chainID: ChainID) -> AssetID {
        AssetID(chainID: chainID, key: "native")
    }

    public var isNative: Bool { key == "native" }

    public var description: String { "\(chainID.rawValue)/\(key)" }
}
