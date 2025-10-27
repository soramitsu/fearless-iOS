import Foundation
import RobinHood
import SSFModels

extension ChainAsset {
    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var identifier: String {
        [chain.identifier, asset.id].joined(separator: " : ")
    }

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath
        switch chainAssetType {
        case .normal, .equilibrium, .none:
            storagePath = StorageCodingPath.account
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            storagePath = StorageCodingPath.tokens
        case .assets:
            storagePath = StorageCodingPath.assetsAccount
        case .soraAsset:
            if isUtility {
                storagePath = StorageCodingPath.account
            } else {
                storagePath = StorageCodingPath.tokens
            }
        }

        return storagePath
    }

    var isBokolo: Bool {
        asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId
    }
}

// Test and utility helper: avoid ambiguity with SSFModels' similarly named API
extension SSFModels.ChainAsset {
    var fearlessStoragePath: StorageCodingPath {
        var path: StorageCodingPath
        switch chainAssetType {
        case .normal, .equilibrium, .none:
            path = .account
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            path = .tokens
        case .assets:
            path = .assetsAccount
        case .soraAsset:
            if isUtility {
                path = .account
            } else {
                path = .tokens
            }
        }

        return path
    }
}
