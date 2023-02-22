import Foundation
import IrohaCrypto

@available(*, deprecated, message: "No longer used in 2.0")
enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"
    case moonbeam = "Moonbeam"
    case moonriver = "Moonriver"
    case moonbaseAlpha = "Moonbase Alpha"

    init?(rawValue: String) {
        switch rawValue {
        case Self.kusama.rawValue: self = .kusama
        case Self.polkadot.rawValue: self = .polkadot
        case Self.westend.rawValue: self = .westend
        case Self.rococo.rawValue: self = .rococo
        case Self.moonbeam.rawValue: self = .moonbeam
        case Self.moonriver.rawValue: self = .moonriver
        case Self.moonbaseAlpha.rawValue: self = .moonbaseAlpha

        #if F_DEV
            case "Polkatrain": self = .polkadot
        #endif

        default: return nil
        }
    }
}

extension Chain {
    var chainId: String {
        switch self {
        case .polkadot: return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama: return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend: return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo: return ".kusamaSecondary"
        case .moonbeam: return "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        case .moonriver: return "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        case .moonbaseAlpha: return "91bc6e169807aaa54802737e1c504b2577d4fafedd5a02c10293b1cd60e39527"
        }
    }

    var addressType: SNAddressType {
        switch self {
        case .polkadot: return .polkadotMain
        case .kusama: return .kusamaMain
        case .westend: return .genericSubstrate
        case .rococo: return .kusamaSecondary
        case .moonbeam: return .moonbeam
        case .moonriver: return .moonriver
        case .moonbaseAlpha: return .moonbaseAlpha
        }
    }
}
