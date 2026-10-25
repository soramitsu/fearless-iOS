import Foundation

enum SubstrateCallPath: CaseIterable {
    var moduleName: String {
        path.moduleName
    }

    var callName: String {
        path.callName
    }

    var path: (moduleName: String, callName: String) {
        switch self {
        case .transfer:
            return (moduleName: "Balances", callName: "transfer")
        case .xorlessTransfer:
            return (moduleName: "LiquidityProxy", callName: "xorless_transfer")
        case .ormlChainTransfer:
            return (moduleName: "Tokens", callName: "transfer")
        case .ormlAssetTransfer:
            return (moduleName: "Currencies", callName: "transfer")
        case .equilibriumAssetTransfer:
            return (moduleName: "EqBalances", callName: "transfer")
        case .defaultTransfer:
            return (moduleName: "Balances", callName: "transfer")
        case .assetsTransfer:
            return (moduleName: "Assets", callName: "transfer")
        case .transferAllowDeath:
            return (moduleName: "Balances", callName: "transfer_allow_death")
        }
    }

    case transfer
    case xorlessTransfer
    case ormlChainTransfer
    case ormlAssetTransfer
    case equilibriumAssetTransfer
    case defaultTransfer
    case assetsTransfer
    case transferAllowDeath
}
