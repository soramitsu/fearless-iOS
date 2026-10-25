import Foundation
import SSFModels

enum XcmCallPath: StorageCodingPathProtocol {
    var moduleName: String {
        path.moduleName
    }

    var itemName: String {
        path.itemName
    }

    var path: (moduleName: String, itemName: String) {
        switch self {
        case .parachainId:
            return (moduleName: "parachainInfo", itemName: "parachainId")

        case .xcmPalletLimitedTeleportAssets:
            return (moduleName: "xcmPallet", itemName: "limited_teleport_assets")

        case .polkadotXcmLimitedTeleportAssets:
            return (moduleName: "polkadotXcm", itemName: "limited_teleport_assets")
        case .polkadotXcmLimitedReserveTransferAssets:
            return (moduleName: "polkadotXcm", itemName: "limited_reserve_transfer_assets")

        case .xTokensTransferMultiasset:
            return (moduleName: "xTokens", itemName: "transfer_multiasset")

        case .bridgeProxyBurn:
            return (moduleName: "bridgeProxy", itemName: "burn")
        case .bridgeProxyTransactions:
            return (moduleName: "BridgeProxy", itemName: "Transactions")
        case .soraBridgeAppBurn:
            return (moduleName: "soraBridgeApp", itemName: "burn")
        }
    }

    case parachainId

    case xcmPalletLimitedTeleportAssets

    case polkadotXcmLimitedTeleportAssets
    case polkadotXcmLimitedReserveTransferAssets

    case xTokensTransferMultiasset

    case bridgeProxyBurn
    case bridgeProxyTransactions
    case soraBridgeAppBurn
}

extension XcmCallPath {
    static var usedRuntimePaths: [String: [String]] {
        var usedRuntimePaths = [String: [String]]()
        for cas in XcmCallPath.allCases {
            usedRuntimePaths[cas.moduleName, default: []].append(cas.itemName)
        }
        return usedRuntimePaths
    }
}
