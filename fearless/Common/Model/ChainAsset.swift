import Foundation

struct ChainAsset {
    let chain: ChainModel
    let asset: AssetModel
}

struct ChainAssetId: Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}
