import Foundation
import SSFUtils
import BigInt

enum AssetStatus: String, Decodable {
    case liquid = "Liquid"
    case frozen = "Frozen"
    case blocked = "Blocked"

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let rawValue = try container.decode(
            String.self)

        switch rawValue {
        case Self.liquid.rawValue:
            self = .liquid
        case Self.frozen.rawValue:
            self = .frozen
        case Self.blocked.rawValue:
            self = .blocked
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

struct AssetAccountInfo: Decodable {
    @StringCodable var balance: BigUInt
    let status: AssetStatus

    var locked: BigUInt {
        switch status {
        case .liquid:
            return .zero
        case .frozen, .blocked:
            return balance
        }
    }

    var frozen: BigUInt {
        switch status {
        case .liquid, .blocked:
            return .zero
        case .frozen:
            return balance
        }
    }

    var blocked: BigUInt {
        switch status {
        case .liquid, .frozen:
            return .zero
        case .blocked:
            return balance
        }
    }
}
