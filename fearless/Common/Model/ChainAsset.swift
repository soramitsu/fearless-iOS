import Foundation

struct ChainAsset: Equatable, Hashable {
    let chain: ChainModel
    let asset: AssetModel

    func uniqueKey(accountId: AccountId) -> String {
        asset.id + chain.chainId + accountId.toHex()
    }
}

struct ChainAssetId: Equatable, Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.id)
    }

    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }
}
