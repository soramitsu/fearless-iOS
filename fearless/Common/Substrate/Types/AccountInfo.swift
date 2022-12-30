import Foundation
import FearlessUtils
import BigInt

struct OrmlAccountInfo: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var frozen: BigUInt
}

struct AccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: AccountData

    init(nonce: UInt32, consumers: UInt32, providers: UInt32, data: AccountData) {
        self.nonce = nonce
        self.consumers = consumers
        self.providers = providers
        self.data = data
    }

    init?(ormlAccountInfo: OrmlAccountInfo?) {
        guard let ormlAccountInfo = ormlAccountInfo else {
            return nil
        }
        nonce = 0
        consumers = 0
        providers = 0

        data = AccountData(
            free: ormlAccountInfo.free,
            reserved: ormlAccountInfo.reserved,
            miscFrozen: ormlAccountInfo.frozen,
            feeFrozen: BigUInt.zero
        )
    }

    init?(equilibriumAccountInfo: EquilibriumAccountInfo?) {
        guard
            let equilibriumAccountInfo = equilibriumAccountInfo,
            case let .positive(value) = equilibriumAccountInfo
        else {
            return nil
        }

        nonce = 0
        consumers = 0
        providers = 0

        data = AccountData(
            free: value,
            reserved: BigUInt.zero,
            miscFrozen: BigUInt.zero,
            feeFrozen: BigUInt.zero
        )
    }
}

struct AccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt
}

extension AccountData {
    var total: BigUInt { free + reserved }
    var frozen: BigUInt { reserved + locked }
    var locked: BigUInt { max(miscFrozen, feeFrozen) }
    var available: BigUInt { free - locked }
}

enum EquilibriumAccountInfo: Codable, Equatable {
    static let positiveField = "Positive"
    static let negativeField = "Negative"

    case positive(value: BigUInt)
    case negative(value: BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let rawValue = try container.decode(String.self)
        switch rawValue {
        case Self.positiveField:
            let value = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .positive(value: value)
        case Self.negativeField:
            let value = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .negative(value: value)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected EquilibriumAccountInfo"
            )
        }
    }
}
