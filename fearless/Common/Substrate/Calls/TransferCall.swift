import Foundation
import SSFUtils
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
        case id
        case target
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

        switch currencyId {
        case .equilibrium:
            try container.encode(currencyId, forKey: .equilibrium)
            try container.encode(dest, forKey: .to)
            try container.encode(String(value), forKey: .value)
        case .soraAsset:
            if case let .accoundId(accountId) = dest {
                try container.encode(currencyId, forKey: .assetId)
                try container.encode(accountId, forKey: .to)
                try container.encode(String(value), forKey: .amount)
            }
        case .assets:
            try container.encode(currencyId, forKey: .id)
            try container.encode(dest, forKey: .target)
            try container.encode(String(value), forKey: .amount)
        case .assetId:
            try container.encode(dest, forKey: .dest)
            try container.encode(currencyId, forKey: .currencyId)
            try container.encode(String(value), forKey: .amount)
        case .none:
            try container.encode(dest, forKey: .dest)
            try container.encode(String(value), forKey: .value)
        default:
            try container.encode(dest, forKey: .dest)
            try container.encode(currencyId, forKey: .currencyId)
            try container.encode(String(value), forKey: .amount)
        }
    }
}
