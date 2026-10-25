import Foundation

public enum CurrencyId: Equatable {
    case ormlAsset(symbol: TokenSymbol?)
    case liquidCrowdloan(liquidCrowdloan: String)
    case foreignAsset(foreignAsset: String)
    case stableAssetPoolToken(stableAssetPoolToken: String)
    case vToken(symbol: TokenSymbol?)
    case vsToken(symbol: TokenSymbol?)
    case stable(symbol: TokenSymbol?)
    case equilibrium(id: String)
    case soraAsset(id: String)
    case assets(id: String)
    case assetId(id: String)
    case token2(id: String)
    case xcm(id: String)

    enum CodingKeys: String, CodingKey {
        case code
        case id
    }
}

extension CurrencyId: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .ormlAsset(symbol):
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
            let assetId32 = try Data(hexStringSSF: id)
            try container.encode(assetId32, forKey: .code)
        case let .assets(id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case let .assetId(id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case let .token2(id):
            var container = encoder.unkeyedContainer()
            try container.encode("Token2")
            try container.encode(id)
        case let .xcm(id):
            var container = encoder.unkeyedContainer()
            try container.encode("XCM")
            try container.encode(id)
        }
    }
}

extension CurrencyId: Decodable {
    public init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "CurrencyId is only ever encoded"
        ))
    }
}
