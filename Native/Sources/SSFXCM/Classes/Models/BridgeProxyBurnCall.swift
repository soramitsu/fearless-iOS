import BigInt
import Foundation
import SSFModels
import SSFUtils

struct BridgeProxyBurnCall: Codable, Equatable {
    let networkId: BridgeTypesGenericNetworkId
    let assetId: SoraAssetId
    let recipient: BridgeTypesGenericAccount
    @StringCodable var amount: BigUInt
}

/// `bridge_types::GenericNetworkId` of the SORA runtime.
enum BridgeTypesGenericNetworkId: Codable, Equatable {
    /// An EVM network by chain id. SORA stores it as an `H256`: the id as 32 big-endian bytes.
    case evm(BigUInt)
    case sub(BridgeTypesSubNetworkId)

    /// The network SORA's bridge uses to reach `chain`; throws when no bridge network covers it.
    init(from chain: ChainModel) throws {
        switch chain.chainBaseType {
        case .substrate:
            guard let networkId = BridgeTypesSubNetworkId(from: chain) else {
                throw XcmError.unsupportedBridgeNetwork(chainId: chain.chainId)
            }
            self = .sub(networkId)
        case .ethereum:
            self = try .evm(Self.evmChainId(from: chain.chainId))
        }
    }

    /// Parses a decimal or `0x` prefixed hexadecimal chain id that fits 256 bits.
    static func evmChainId(from string: String) throws -> BigUInt {
        let isHex = string.lowercased().hasPrefix("0x")
        let digits = isHex ? String(string.dropFirst(2)) : string
        let allowed = CharacterSet(charactersIn: isHex ? "0123456789abcdefABCDEF" : "0123456789")

        // `BigUInt(_:radix:)` reads "" as 0 and accepts a sign, so the digits are checked first.
        guard !digits.isEmpty,
              digits.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              let value = BigUInt(digits, radix: isHex ? 16 : 10),
              value.bitWidth <= 256 else
        {
            throw XcmError.invalidEvmChainId(string)
        }

        return value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .evm(id):
            let bytes = id.serialize()
            try container.encode("EVM")
            try container.encode(BytesCodable(
                wrappedValue: Data(repeating: 0, count: 32 - bytes.count) + bytes
            ))
        case let .sub(bridgeTypesSubNetworkId):
            try container.encode("Sub")
            try container.encode(bridgeTypesSubNetworkId)
        }
    }
}

/// `bridge_types::SubNetworkId` of the SORA runtime: the substrate networks SORA bridges to.
enum BridgeTypesSubNetworkId: Codable, Equatable {
    case mainnet
    case kusama
    case polkadot
    case rococo
    case liberland

    /// `nil` when no SORA bridge network reaches the chain.
    init?(from chain: ChainModel) {
        switch chain.knownChainEquivalent {
        case .soraMain:
            self = .mainnet
            return
        case .liberland:
            self = .liberland
            return
        default:
            break
        }

        // Relay chains and their parachains go through the bridge of their relay network.
        switch ChainEcosystem.defineEcosystem(chain: chain) {
        case .polkadot:
            self = .polkadot
        case .kusama:
            self = .kusama
        case .rococo:
            self = .rococo
        case .westend, .ethereum, .unknown:
            return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .mainnet:
            try container.encode("Mainnet")
        case .kusama:
            try container.encode("Kusama")
        case .polkadot:
            try container.encode("Polkadot")
        case .rococo:
            try container.encode("Rococo")
        case .liberland:
            try container.encode("Liberland")
        }
        try container.encodeNil()
    }
}

enum BridgeTypesGenericAccount: Codable {
    case evm(AccountId)
    case sora(AccountId)
    case liberland(AccountId)
    case parachain(XcmVersionedMultiLocation)
    case unknown
    case root

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .evm(accountId):
            try container.encode("EVM")
            try container.encode(accountId)
        case let .sora(accountId):
            try container.encode("Sora")
            try container.encode(accountId)
        case let .parachain(xcmVersionedMultiLocation):
            try container.encode("Parachain")
            try container.encode(xcmVersionedMultiLocation)
        case .unknown:
            try container.encode("Unknown")
            try container.encodeNil()
        case .root:
            try container.encode("Root")
            try container.encodeNil()
        case let .liberland(accountId):
            try container.encode("Liberland")
            try container.encode(accountId)
        }
    }
}

extension BridgeTypesGenericAccount: Equatable {
    static func == (lhs: BridgeTypesGenericAccount, rhs: BridgeTypesGenericAccount) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.root, .root):
            return true
        case let (.evm(lhsValue), .evm(rhsValue)):
            return lhsValue == rhsValue
        case let (.sora(lhsValue), .sora(rhsValue)):
            return lhsValue == rhsValue
        case let (.parachain(lhsValue), .parachain(rhsValue)):
            return lhsValue == rhsValue
        case let (.liberland(lhsValue), .liberland(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
