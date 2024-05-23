import Foundation
import RobinHood
import SSFModels

extension ChainAsset {
    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var identifier: String {
        [chain.identifier, asset.identifier].joined(separator: " : ")
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
