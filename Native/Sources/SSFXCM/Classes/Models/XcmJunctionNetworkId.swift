import Foundation
import SSFModels
import SSFUtils

/// The `NetworkId` of an XCM V3, V4 or V5 junction. Junctions hold it as `Option<NetworkId>`: a
/// junction without a network carries `nil`.
enum XcmJunctionNetworkId: Codable, Equatable {
    case byGenesis(_ genesisHash: Data)
    case polkadot
    case kusama
    case westend
    case rococo
    case ethereum(chainId: UInt64)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .byGenesis(genesisHash):
            try container.encode("ByGenesis")
            try container.encode(BytesCodable(wrappedValue: genesisHash))
        case .polkadot:
            try container.encode("Polkadot")
            try container.encode(JSON.null)
        case .kusama:
            try container.encode("Kusama")
            try container.encode(JSON.null)
        case .westend:
            try container.encode("Westend")
            try container.encode(JSON.null)
        case .rococo:
            try container.encode("Rococo")
            try container.encode(JSON.null)
        case let .ethereum(chainId):
            try container.encode("Ethereum")
            try container.encode(["chain_id": String(chainId)])
        }
    }

    /// The network an account of `ecosystem` is named with in `version`, or `nil` when the junction
    /// should carry none. V5 has no `Westend` and `Rococo` variants and names them by genesis hash.
    static func from(
        ecosystem: ChainEcosystem,
        version: XcmCallFactoryVersion
    ) -> XcmJunctionNetworkId? {
        switch ecosystem {
        case .polkadot:
            return .polkadot
        case .kusama:
            return .kusama
        case .westend:
            return version == .V5 ? genesis(of: .westend) : .westend
        case .rococo:
            return version == .V5 ? genesis(of: .rococo) : .rococo
        case .ethereum, .unknown:
            return nil
        }
    }

    private static func genesis(of chain: Chain) -> XcmJunctionNetworkId? {
        (try? Data(hexStringSSF: chain.genesisHash)).map { .byGenesis($0) }
    }
}
