import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels
#if canImport(FearlessKeys)
    import FearlessKeys
#endif

enum BlockExplorerApiKey {
    case etherscan
    case polygonscan
    case bscscan
    case oklink
    case opMainnet

    init?(chainId: String) {
        switch chainId {
        case "1", "5":
            self = .etherscan
        case "137":
            self = .polygonscan
        case "56", "97":
            self = .bscscan
        case "195":
            self = .oklink
        case "10":
            self = .opMainnet
        default:
            return nil
        }
    }

    var value: String {
        switch self {
        case .etherscan:
            #if canImport(FearlessKeys) && DEBUG
                return BlockExplorerApiKeysDebug.etherscanApiKey
            #else
                return BlockExplorerApiKeys.etherscanApiKey
            #endif
        case .polygonscan:
            #if canImport(FearlessKeys) && DEBUG
                return BlockExplorerApiKeysDebug.polygonscanApiKey
            #else
                return BlockExplorerApiKeys.polygonscanApiKey
            #endif
        case .bscscan:
            #if canImport(FearlessKeys) && DEBUG
                return BlockExplorerApiKeysDebug.bscscanApiKey
            #else
                return BlockExplorerApiKeys.bscscanApiKey
            #endif
        case .oklink:
            #if canImport(FearlessKeys) && DEBUG
                return BlockExplorerApiKeysDebug.oklinkApiKey
            #else
                return BlockExplorerApiKeys.oklinkApiKey
            #endif
        case .opMainnet:
            #if canImport(FearlessKeys) && DEBUG
                return BlockExplorerApiKeysDebug.opMainnetApiKey
            #else
                return BlockExplorerApiKeys.opMainnetApiKey
            #endif
        }
    }
}
