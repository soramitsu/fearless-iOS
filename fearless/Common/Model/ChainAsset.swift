import Foundation

typealias ChainAssetKey = String

struct ChainAsset: Equatable, Hashable {
    let chain: ChainModel
    let asset: AssetModel

    var chainAssetType: ChainAssetType {
        asset.type
    }

    var currencyId: CurrencyId? {
        switch chainAssetType {
        case .normal:
            return nil
        case .ormlChain, .ormlAsset:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.token(symbol: tokenSymbol)
        case .foreignAsset:
            guard let foreignAssetId = asset.foreignAssetId else {
                return nil
            }
            return CurrencyId.foreignAsset(foreignAsset: foreignAssetId)
        }
    }

    func uniqueKey(accountId: AccountId) -> ChainAssetKey {
        [asset.id, chain.chainId, accountId.toHex()].joined(separator: ":")
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

enum ChainAssetType: String, Codable {
    case normal
    case ormlChain
    case ormlAsset
    case foreignAsset
}
