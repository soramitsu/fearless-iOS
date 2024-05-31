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
    case soraTest = "SORA Test"
    case ternoa = "Ternoa Mainnet"
    case equilibrium = "Equilibrium"
    case reef = "Reef Mainnet"
    case scuba = "Reef Scuba Testnet"
    case liberland = "Liberland"

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
        case Self.ternoa.rawValue: self = .ternoa
        case Self.equilibrium.rawValue: self = .equilibrium
        case Self.reef.rawValue: self = .reef
        case Self.scuba.rawValue: self = .scuba
        case Self.liberland.rawValue: self = .liberland

        #if F_DEV
            case "Polkatrain": self = .polkadot
        #endif

        default: return nil
        }
    }

    init?(chainId: String) {
        switch chainId {
        case Self.kusama.genesisHash: self = .kusama
        case Self.polkadot.genesisHash: self = .polkadot
        case Self.westend.genesisHash: self = .westend
        case Self.rococo.genesisHash: self = .rococo
        case Self.moonbeam.genesisHash: self = .moonbeam
        case Self.moonriver.genesisHash: self = .moonriver
        case Self.moonbaseAlpha.genesisHash: self = .moonbaseAlpha
        case Self.soraMain.genesisHash: self = .soraMain
        case Self.ternoa.genesisHash: self = .ternoa
        case Self.equilibrium.genesisHash: self = .equilibrium
        case Self.reef.genesisHash: self = .reef
        case Self.scuba.genesisHash: self = .scuba
        case Self.liberland.genesisHash: self = .liberland
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
        case .soraTest: return "3266816be9fa51b32cfea58d3e33ca77246bc9618595a4300e44c8856a8d8a17"
        case .ternoa: return "6859c81ca95ef624c9dfe4dc6e3381c33e5d6509e35e147092bfbc780f777c4e"
        case .equilibrium: return "89d3ec46d2fb43ef5a9713833373d5ea666b092fa8fd68fbc34596036571b907"
        case .reef: return "7834781d38e4798d548e34ec947d19deea29df148a7bf32484b7b24dacf8d4b7"
        case .scuba: return "b414a8602b2251fa538d38a9322391500bd0324bc7ac6048845d57c37dd83fe6"
        case .liberland: return "6bd89e052d67a45bb60a9a23e8581053d5e0d619f15cb9865946937e690c42d6"
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot, .ternoa, .equilibrium, .reef, .scuba: return 1
        case .kusama, .westend, .rococo, .moonbeam, .soraMain, .soraTest, .liberland: return 4
        case .moonriver, .moonbaseAlpha: return 12
        }
    }
}
