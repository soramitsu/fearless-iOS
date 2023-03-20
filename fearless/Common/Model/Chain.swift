import Foundation
import IrohaCrypto

enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"
    case moonbeam = "Moonbeam"
    case moonriver = "Moonriver"
    case moonbaseAlpha = "Moonbase Alpha"
    case soraMain = "SORA Mainnet"

    init?(rawValue: String) {
        switch rawValue {
        case Self.kusama.rawValue: self = .kusama
        case Self.polkadot.rawValue: self = .polkadot
        case Self.westend.rawValue: self = .westend
        case Self.rococo.rawValue: self = .rococo
        case Self.moonbeam.rawValue: self = .moonbeam
        case Self.moonriver.rawValue: self = .moonriver
        case Self.moonbaseAlpha.rawValue: self = .moonbaseAlpha
        case Self.soraMain.rawValue: self = .soraMain

        #if F_DEV
            case "Polkatrain": self = .polkadot
        #endif

        default: return nil
        }
    }

    var genesisHash: String {
        switch self {
        case .polkadot: return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama: return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend: return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo: return "1ab7fbd1d7c3532386268ec23fe4ff69f5bb6b3e3697947df3a2ec2786424de3"
        case .moonbeam: return "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        case .moonriver: return "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        case .moonbaseAlpha: return "91bc6e169807aaa54802737e1c504b2577d4fafedd5a02c10293b1cd60e39527"
        case .soraMain: return "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot: return 1
        case .kusama, .westend, .rococo, .moonbeam: return 4
//            Need to check
        case .soraMain: return 4
        case .moonriver, .moonbaseAlpha: return 12
        }
    }
}
