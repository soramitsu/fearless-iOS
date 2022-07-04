import Foundation
import FearlessUtils
import BigInt

struct TokenSymbol {
    let symbol: String
}

extension TokenSymbol: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(symbol.uppercased())
        try container.encodeNil()
    }
}

enum CurrencyId {
    case token(symbol: TokenSymbol?)
    case liquidCrowdloan(liquidCrowdloan: String)
    case foreignAsset(foreignAsset: String)
    case stableAssetPoolToken(stableAssetPoolToken: String)
    case vToken(symbol: TokenSymbol?)
    case vsToken(symbol: TokenSymbol?)
    case stable(symbol: TokenSymbol?)
}

extension CurrencyId: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .token(symbol):
            try container.encode("Token")
            try container.encode(symbol)
        case let .liquidCrowdloan(liquidCrowdloan):
            try container.encode("LiquidCrowdloan")
            try container.encode(liquidCrowdloan)
        case let .foreignAsset(foreignAsset):
            try container.encode("ForeignAsset")
            try container.encode(foreignAsset)
        case let .stableAssetPoolToken(stableAssetPoolToken):
            try container.encode("StableAssetPoolToken")
            try container.encode(stableAssetPoolToken)
        case let .vToken(symbol):
            try container.encode("VToken")
            try container.encode(symbol)
        case let .vsToken(symbol):
            try container.encode("VSToken")
            try container.encode(symbol)
        case let .stable(symbol):
            try container.encode("Stable")
            try container.encode(symbol)
        }
    }
}

struct TransferCall: Codable {
    enum CodingKeys: String, CodingKey {
        case dest
        case value
        case amount
        case currencyId = "currency_id"
    }

    var dest: MultiAddress
    @StringCodable var value: BigUInt
    let currencyId: CurrencyId?

    init(dest: MultiAddress, value: BigUInt, currencyId: CurrencyId?) {
        self.dest = dest
        self.value = value
        self.currencyId = currencyId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dest = try container.decode(MultiAddress.self, forKey: .dest)
        let valueString = try container.decode(String.self, forKey: .value)
        value = BigUInt(valueString) ?? BigUInt.zero
        currencyId = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(dest, forKey: .dest)

        let isOrml = currencyId != nil

        if isOrml {
            try container.encode(currencyId, forKey: .currencyId)
            try container.encode(String(value), forKey: .amount)
        } else {
            try container.encode(String(value), forKey: .value)
        }
    }
}
