import Foundation
import RobinHood

typealias ChainAssetKey = String

struct ChainAsset: Equatable, Hashable, Identifiable {
    let chain: ChainModel
    let asset: AssetModel

    var chainAssetType: ChainAssetType {
        chain.assets.first(where: { $0.assetId == asset.id })?.type ?? .normal
    }

    var isUtility: Bool {
        chain.assets.first(where: { $0.assetId == asset.id })?.isUtility ?? false
    }

    var identifier: String {
        chain.identifier + asset.identifier
    }

    var currencyId: CurrencyId? {
        switch chainAssetType {
        case .normal:
            if chain.isSora, isUtility {
                guard let currencyId = asset.currencyId else {
                    return nil
                }
                return CurrencyId.soraAsset(id: currencyId)
            }
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
        case .liquidCrowdloan:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return CurrencyId.liquidCrowdloan(liquidCrowdloan: currencyId)
        case .vToken:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.vToken(symbol: tokenSymbol)
        case .vsToken:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.vsToken(symbol: tokenSymbol)
        case .stable:
            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
            return CurrencyId.stable(symbol: tokenSymbol)
        case .equilibrium:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return CurrencyId.equilibrium(id: currencyId)
        case .soraAsset:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return CurrencyId.soraAsset(id: currencyId)
        }
    }

    func uniqueKey(accountId: AccountId) -> ChainAssetKey {
        [asset.id, chain.chainId, accountId.toHex()].joined(separator: ":")
    }
}

struct ChainAssetId: Equatable, Codable, Hashable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.id)
    }

    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var stakingType: StakingType? {
        chain.assets.first(where: { $0.assetId == asset.id })?.staking
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
            .soraAsset:
            storagePath = StorageCodingPath.tokens
        }

        return storagePath
    }

    var debugName: String {
        "\(chain.name)-\(asset.name)"
    }

    var hasStaking: Bool {
        let model: ChainAssetModel? = chain.assets.first { $0.asset.id == asset.id }
        return model?.staking != nil
    }
}

enum ChainAssetType: String, Codable {
    case normal
    case ormlChain
    case ormlAsset
    case foreignAsset
    case stableAssetPoolToken
    case liquidCrowdloan
    case vToken
    case vsToken
    case stable
    case equilibrium
    case soraAsset
}
