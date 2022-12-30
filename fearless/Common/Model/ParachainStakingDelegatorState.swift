import Foundation
import FearlessUtils
import BigInt

enum DelegatorStatus: String, Codable {
    case active = "Active"
    case leaving = "Leaving"

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.active.rawValue:
            self = .active
        case Self.leaving.rawValue:
            self = .leaving
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

struct ParachainStakingDelegatorState: Codable, Equatable {
    let id: AccountId
    let delegations: [ParachainStakingDelegation]
    @StringCodable var total: BigUInt
    @StringCodable var lessTotal: BigUInt
    let status: DelegatorStatus
}
