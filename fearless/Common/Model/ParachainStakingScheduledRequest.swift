import Foundation
import BigInt
import FearlessUtils

enum ParachainStakingDelegationAction: Decodable, Equatable {
    case revoke(amount: BigUInt)
    case decrease(amount: BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)
        let amount = try container.decode(StringScaleMapper<BigUInt>.self)

        switch type.lowercased() {
        case "revoke":
            self = .revoke(amount: amount.value)
        case "decrease":
            self = .decrease(amount: amount.value)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

struct ParachainStakingScheduledRequest: Decodable, Equatable {
    let delegator: AccountId
    @StringCodable var whenExecutable: UInt32
    let action: ParachainStakingDelegationAction
}
