import Foundation
import SSFModels

enum ExistentialDepositCurrencyId {
    case token(tokenSymbol: String)
    case token2(tokenSymbol: String)
    case liquidCrowdloan(symbol: String)
    case foreignAsset(tokenSymbol: UInt16)
    case stableAssetPoolToken(stableAssetPoolToken: String)
    case vToken(tokenSymbol: String)
    case vsToken(tokenSymbol: String)
    case stable(tokenSymbol: String)

    init?(from currencyId: SSFModels.CurrencyId?) {
        guard let currencyId = currencyId else {
            return nil
        }
        switch currencyId {
        case let .ormlAsset(symbol):
            guard let symbol = symbol?.symbol else {
                return nil
            }
            self = .token(tokenSymbol: symbol.uppercased())
        case let .foreignAsset(foreignAsset):
            guard let uint = UInt16(foreignAsset) else {
                return nil
            }
            self = .foreignAsset(tokenSymbol: uint)
        case let .stableAssetPoolToken(stableAssetPoolToken):
            self = .stableAssetPoolToken(stableAssetPoolToken: stableAssetPoolToken)
        case let .liquidCrowdloan(symbol):
            self = .liquidCrowdloan(symbol: symbol)
        case let .vsToken(symbol):
            guard let symbol = symbol?.symbol else {
                return nil
            }
            self = .vsToken(tokenSymbol: symbol.uppercased())
        case let .vToken(symbol):
            guard let symbol = symbol?.symbol else {
                return nil
            }
            self = .vToken(tokenSymbol: symbol.uppercased())
        case let .stable(symbol):
            guard let symbol = symbol?.symbol else {
                return nil
            }
            self = .stable(tokenSymbol: symbol.uppercased())
        case .equilibrium:
            // existential deposit for equilibrium fetch by constants, becouse this chain now unuse subassets
            // when sub-assets are added, this part needs to be researched
            return nil
        case .soraAsset:
            // Sora chain zero ED
            return nil
        case .assets:
            return nil
        case let .assetId(id):
            self = .token(tokenSymbol: id)
        case let .token2(id):
            self = .token(tokenSymbol: id)
        case .xcm:
            return nil
        }
    }
}

extension ExistentialDepositCurrencyId: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .token(symbol):
            try container.encode(symbol, forKey: .token)
        case let .token2(symbol):
            try container.encode(symbol, forKey: .token2)
        case let .foreignAsset(foreignAsset):
            try container.encode(foreignAsset, forKey: .foreignAsset)
        case let .stableAssetPoolToken(stableAssetPoolToken):
            try container.encode(stableAssetPoolToken, forKey: .stableAssetPoolToken)
        case let .liquidCrowdloan(symbol):
            try container.encode(String(symbol), forKey: .liquidCrowdloan)
        case let .vToken(symbol):
            try container.encode(symbol, forKey: .vToken)
        case let .vsToken(symbol):
            try container.encode(symbol, forKey: .vsToken)
        case let .stable(symbol):
            try container.encode(symbol, forKey: .stable)
        }
    }
}
