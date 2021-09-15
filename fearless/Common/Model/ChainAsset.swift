import Foundation

struct ChainAsset: Equatable {
    let chain: ChainModel
    let asset: AssetModel
}

struct ChainAssetId: Equatable, Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}
