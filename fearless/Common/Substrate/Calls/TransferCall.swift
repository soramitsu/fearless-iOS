import Foundation
import FearlessUtils
import BigInt
import SSFModels

struct TokenSymbol: Equatable {
    let symbol: String
}

extension TokenSymbol: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(symbol.uppercased())
        try container.encodeNil()
    }
}

enum CurrencyId: Equatable {
    case token(symbol: TokenSymbol?)
    case liquidCrowdloan(liquidCrowdloan: String)
    case foreignAsset(foreignAsset: String)
    case stableAssetPoolToken(stableAssetPoolToken: String)
    case vToken(symbol: TokenSymbol?)
    case vsToken(symbol: TokenSymbol?)
    case stable(symbol: TokenSymbol?)
    case equilibrium(id: String)
    case soraAsset(id: String)

    enum CodingKeys: String, CodingKey {
        case code
    }
}

extension CurrencyId: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .token(symbol):
            var container = encoder.unkeyedContainer()
            try container.encode("Token")
            try container.encode(symbol)
        case let .liquidCrowdloan(liquidCrowdloan):
            var container = encoder.unkeyedContainer()
            try container.encode("LiquidCrowdloan")
            try container.encode(liquidCrowdloan)
        case let .foreignAsset(foreignAsset):
            var container = encoder.unkeyedContainer()
            try container.encode("ForeignAsset")
            try container.encode(foreignAsset)
        case let .stableAssetPoolToken(stableAssetPoolToken):
            var container = encoder.unkeyedContainer()
            try container.encode("StableAssetPoolToken")
            try container.encode(stableAssetPoolToken)
        case let .vToken(symbol):
            var container = encoder.unkeyedContainer()
            try container.encode("VToken")
            try container.encode(symbol)
        case let .vsToken(symbol):
            var container = encoder.unkeyedContainer()
            try container.encode("VSToken")
            try container.encode(symbol)
        case let .stable(symbol):
            var container = encoder.unkeyedContainer()
            try container.encode("Stable")
            try container.encode(symbol)
        case let .equilibrium(id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case let .soraAsset(id):
            var container = encoder.container(keyedBy: CodingKeys.self)
            let assetId32 = try Data(hexString: id)
            try container.encode(assetId32, forKey: .code)
        }
    }
}

// swiftlint:disable identifier_name
struct TransferCall: Codable {
    enum CodingKeys: String, CodingKey {
        case dest
        case value
        case amount
        case currencyId = "currency_id"
        case equilibrium = "asset"
        case to
        case assetId = "asset_id"
    }

    var dest: MultiAddress
    @StringCodable var value: BigUInt
    let currencyId: SSFModels.CurrencyId?

    init(dest: MultiAddress, value: BigUInt, currencyId: SSFModels.CurrencyId?) {
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
        let isOrml = currencyId != nil

        if isOrml {
            if case .equilibrium = currencyId {
                try container.encode(currencyId, forKey: .equilibrium)
                try container.encode(dest, forKey: .to)
                try container.encode(String(value), forKey: .value)
            } else if case .soraAsset = currencyId, case let .accoundId(accountId) = dest {
                try container.encode(currencyId, forKey: .assetId)
                try container.encode(accountId, forKey: .to)
                try container.encode(String(value), forKey: .amount)
            } else {
                try container.encode(dest, forKey: .dest)
                try container.encode(currencyId, forKey: .currencyId)
                try container.encode(String(value), forKey: .amount)
            }
        } else {
            try container.encode(dest, forKey: .dest)
            try container.encode(String(value), forKey: .value)
        }
    }
}
