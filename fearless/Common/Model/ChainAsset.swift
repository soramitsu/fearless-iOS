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
            guard let foreignAssetId = asset.currencyId else {
                return nil
            }
            return CurrencyId.foreignAsset(foreignAsset: foreignAssetId)
        case .stableAssetPoolToken:
            guard let stableAssetPoolTokenId = asset.currencyId else {
                return nil
            }
            return CurrencyId.stableAssetPoolToken(stableAssetPoolToken: stableAssetPoolTokenId)
        case .liquidCroadloan:
            guard
                let currencyId = asset.currencyId,
                let liquidCroadloanId = UInt16(currencyId)
            else {
                return nil
            }
            let liquidCroadloan = LiquidCroadloan(symbol: liquidCroadloanId)
            return CurrencyId.liquidCroadloan(symbol: liquidCroadloan)
        case .vToken:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.vToken(symbol: tokenSymbol)
        case .vsToken:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.vsToken(symbol: tokenSymbol)
        case .stable:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.stable(symbol: tokenSymbol)
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

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath
        switch chainAssetType {
        case .normal:
            storagePath = StorageCodingPath.account
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCroadloan,
            .vToken,
            .vsToken,
            .stable:
            storagePath = StorageCodingPath.tokens
        }

        return storagePath
    }
}

enum ChainAssetType: String, Codable {
    case normal
    case ormlChain
    case ormlAsset
    case foreignAsset
    case stableAssetPoolToken
    case liquidCroadloan
    case vToken
    case vsToken
    case stable
}
