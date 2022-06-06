import Foundation

enum ExistentialDepositCurrencyId {
    case token(tokenSymbol: String)
    case foreignAsset(tokenSymbol: UInt16)
    case stableAssetPoolToken(stableAssetPoolToken: UInt16)

    init?(from currencyId: CurrencyId?) {
        guard let currencyId = currencyId else {
            return nil
        }
        switch currencyId {
        case let .token(symbol):
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
            guard let uint = UInt16(stableAssetPoolToken) else {
                return nil
            }
            self = .stableAssetPoolToken(stableAssetPoolToken: uint)
        }
    }
}

extension ExistentialDepositCurrencyId: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .token(symbol):
            try container.encode(symbol, forKey: .token)
        case let .foreignAsset(foreignAsset):
            try container.encode(foreignAsset, forKey: .foreignAsset)
        case let .stableAssetPoolToken(stableAssetPoolToken):
            try container.encode(stableAssetPoolToken, forKey: .stableAssetPoolToken)
        }
    }
}
