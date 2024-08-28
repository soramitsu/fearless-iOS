import Foundation
import RobinHood
import SSFModels

extension ChainAsset {
    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath

        switch chainAssetType {
        case .substrate(substrateType: let substrateType):
            switch substrateType {
            case .normal, .equilibrium:
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
        case .ethereum(ethereumType: let ethereumType):
            storagePath = .account
        case .ton(tonType: let tonType):
            storagePath = .tokens
        }

        return storagePath
    }

    var isBokolo: Bool {
        asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId
    }
}
