import Foundation
import IrohaCrypto

enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
}

extension Chain {
    var addressType: SNAddressType {
        switch self {
        case .polkadot:
            return .polkadotMain
        case .kusama:
            return .kusamaMain
        case .westend:
            return .genericSubstrate
        }
    }

    var balanceModuleIndex: UInt8 {
        switch self {
        case .polkadot:
            return 5
        default:
            return 4
        }
    }

    var transferCallIndex: UInt8 { 0 }

    var keepAliveTransferCallIndex: UInt8 { 3 }
}
