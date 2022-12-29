import Foundation
import FearlessUtils
import BigInt

enum BondExtra: Codable {
    case freeBalance(amount: BigUInt)
    case rewards(amount: BigUInt)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .freeBalance(amount):
            var container = encoder.unkeyedContainer()
            try container.encode("FreeBalance")
            try container.encode(amount.description)
        case let .rewards(amount):
            var container = encoder.unkeyedContainer()
            try container.encode("Rewards")
            try container.encode(amount.description)
        }
    }
}

struct PoolBondMoreCall: Codable {
    let extra: BondExtra
}
