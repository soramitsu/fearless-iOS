import Foundation
import RobinHood
import SSFModels

extension ChainAsset {
    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var identifier: String {
        [chain.identifier, asset.id].joined(separator: " : ")
    }

    var storagePath: StorageCodingPath {
        guard let substrateType = chainAssetType else {
            return .account
        }

        switch substrateType {
        case .normal, .equilibrium:
            return .account
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
            return .tokens
        case .assets:
            return .assetsAccount
        case .soraAsset:
            return isUtility ? .account : .tokens
        }
    }

    var isBokolo: Bool {
        asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId
    }
}

// Test and utility helper: avoid ambiguity with SSFModels' similarly named API
extension SSFModels.ChainAsset {
    var fearlessStoragePath: StorageCodingPath {
        guard let substrateType = chainAssetType else {
            return .account
        }

        switch substrateType {
        case .normal, .equilibrium:
            return .account
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
            return .tokens
        case .assets:
            return .assetsAccount
        case .soraAsset:
            return isUtility ? .account : .tokens
        }
    }
}

extension ChainAsset {
    var substrateAssetTypeCompatibility: SubstrateAssetType? {
        chainAssetType
    }

    var isSoraAssetType: Bool {
        chainAssetType == .soraAsset
    }
}
