import Foundation

extension Chain {
    var genesisHash: String {
        switch self {
        case .polkadot:
            return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama:
            return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend:
            return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        }
    }

    var existentialDeposit: Decimal {
        switch self {
        case .polkadot:
            return Decimal(string: "1")!
        case .kusama:
            return Decimal(string: "0.001666666666")!
        case .westend:
            return Decimal(string: "0.01")!
        }
    }
}
