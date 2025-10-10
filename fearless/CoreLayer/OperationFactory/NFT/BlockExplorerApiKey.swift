import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels
#if canImport(FearlessKeys)
    import FearlessKeys
#else
    // Fallback stubs when FearlessKeys is not available (PR/local builds)
    enum BlockExplorerApiKeys {
        static let etherscanApiKey = ""
        static let polygonscanApiKey = ""
        static let bscscanApiKey = ""
        static let oklinkApiKey = ""
        static let opMainnetApiKey = ""
    }

    enum BlockExplorerApiKeysDebug {
        static let etherscanApiKey = ""
        static let polygonscanApiKey = ""
        static let bscscanApiKey = ""
        static let oklinkApiKey = ""
        static let opMainnetApiKey = ""
    }
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
            #if DEBUG
                return BlockExplorerApiKeysDebug.etherscanApiKey
            #else
                return BlockExplorerApiKeys.etherscanApiKey
            #endif
        case .polygonscan:
            #if DEBUG
                return BlockExplorerApiKeysDebug.polygonscanApiKey
            #else
                return BlockExplorerApiKeys.polygonscanApiKey
            #endif
        case .bscscan:
            #if DEBUG
                return BlockExplorerApiKeysDebug.bscscanApiKey
            #else
                return BlockExplorerApiKeys.bscscanApiKey
            #endif
        case .oklink:
            #if DEBUG
                return BlockExplorerApiKeysDebug.oklinkApiKey
            #else
                return BlockExplorerApiKeys.oklinkApiKey
            #endif
        case .opMainnet:
            #if DEBUG
                return BlockExplorerApiKeysDebug.opMainnetApiKey
            #else
                return BlockExplorerApiKeys.opMainnetApiKey
            #endif
        }
    }
}
