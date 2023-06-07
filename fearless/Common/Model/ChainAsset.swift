import Foundation
import RobinHood
import SSFModels

extension ChainAsset: Identifiable {
    public var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    public var identifier: String {
        chain.identifier + asset.identifier
    }

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath
        switch chainAssetType {
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
            .soraAsset,
            .assetId,
            .token2:
            storagePath = StorageCodingPath.tokens
        case .assets:
            storagePath = StorageCodingPath.assetsAccount
        }

        return storagePath
    }
}
