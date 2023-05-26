import Foundation
import SSFUtils

enum UpdateRoleCase: Codable {
    case set(AccountId)
    case remove

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .set(accountId):
            try container.encode("Set")
            try container.encode(accountId)
        case .remove:
            try container.encode("Remove")
        }
    }
}

struct NominationPoolsUpdateRolesCall: Codable {
    let poolId: String
    let newRoot: UpdateRoleCase?
    let newNominator: UpdateRoleCase?
    let newBouncer: UpdateRoleCase?
}
