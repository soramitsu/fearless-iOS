import Foundation
import SSFModels

enum XcmChainType {
    case relaychain
    case nativeParachain
    case parachain
    case soraMainnet
    case liberland

    static func determineChainType(for chain: ChainModel) throws -> XcmChainType {
        guard let paraId = UInt32(chain.paraId ?? "") else {
            if chain.knownChainEquivalent == .soraMain || chain.knownChainEquivalent == .soraTest {
                return .soraMainnet
            }
            if chain.knownChainEquivalent == .liberland {
                return .liberland
            }
            return .relaychain // we don't have path for parachainId in relaychain and snapshot
            // throw error
        }

        switch paraId {
        case let paraId where SubstrateConstants.isNativeParachainRange.contains(Int(paraId)):
            return .nativeParachain
        case let paraId where SubstrateConstants.isNoNativeParachainRange.contains(Int(paraId)):
            return .parachain
        default:
            throw XcmError.invalidParachainRange
        }
    }
}
