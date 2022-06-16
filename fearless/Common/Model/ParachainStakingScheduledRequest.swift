import Foundation
import BigInt
import FearlessUtils

enum ParachainStakingDelegationAction: Decodable, Equatable {
    case revoke(amount: BigUInt)
    case decrease(amount: BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)
        let amountString = try container.decode(String.self)
        let amount = BigUInt(stringLiteral: amountString)

        switch type.lowercased() {
        case "revoke":
            self = .revoke(amount: amount)
        case "decrease":
            self = .decrease(amount: amount)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

struct ParachainStakingScheduledRequest: Decodable {
    let delegator: AccountId
    @StringCodable var whenExecutable: UInt32
    let action: ParachainStakingDelegationAction
}
