import Foundation

struct ChainAsset: Equatable {
    let chain: ChainModel
    let asset: AssetModel
}

struct ChainAssetId: Equatable, Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
    }

    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }
}
