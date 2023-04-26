import Foundation
import RobinHood
import SSFModels

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

    var isNative: Bool {
        chain.assets.first(where: { $0.assetId == asset.id })?.isNative ?? false
    }

    var identifier: String {
        chain.identifier + asset.identifier
    }

    var currencyId: SSFModels.CurrencyId? {
        switch chainAssetType {
        case .normal:
            if chain.isSora, isUtility {
                guard let currencyId = asset.currencyId else {
                    return nil
                }
                return SSFModels.CurrencyId.soraAsset(id: currencyId)
            }
            return nil
        case .ormlChain, .ormlAsset:
            let tokenSymbol = SSFModels.TokenSymbol(symbol: asset.symbol)
            return SSFModels.CurrencyId.token(symbol: tokenSymbol)
        case .foreignAsset:
            guard let foreignAssetId = asset.currencyId else {
                return nil
            }
            return SSFModels.CurrencyId.foreignAsset(foreignAsset: foreignAssetId)
        case .stableAssetPoolToken:
            guard let stableAssetPoolTokenId = asset.currencyId else {
                return nil
            }
            return SSFModels.CurrencyId.stableAssetPoolToken(stableAssetPoolToken: stableAssetPoolTokenId)
        case .liquidCrowdloan:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return SSFModels.CurrencyId.liquidCrowdloan(liquidCrowdloan: currencyId)
        case .vToken:
            let tokenSymbol = SSFModels.TokenSymbol(symbol: asset.symbol)
            return SSFModels.CurrencyId.vToken(symbol: tokenSymbol)
        case .vsToken:
            let tokenSymbol = SSFModels.TokenSymbol(symbol: asset.symbol)
            return SSFModels.CurrencyId.vsToken(symbol: tokenSymbol)
        case .stable:
            let tokenSymbol = SSFModels.TokenSymbol(symbol: asset.symbol)
            return SSFModels.CurrencyId.stable(symbol: tokenSymbol)
        case .equilibrium:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return SSFModels.CurrencyId.equilibrium(id: currencyId)
        case .soraAsset:
            guard let currencyId = asset.currencyId else {
                return nil
            }
            return SSFModels.CurrencyId.soraAsset(id: currencyId)
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

//// MARK: - ChainAssetProtocol
//
// extension ChainAsset: ChainAssetProtocol {
//    var chainModel: ChainModelProtocol {
//        chain
//    }
//
//    var assetModel: AssetModelProtocol {
//        asset
//    }
// }
