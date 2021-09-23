import Foundation
import BigInt
import FearlessUtils

struct BalanceLock: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case amount
        case reason
    }

    let identifier: String
    @StringCodable var amount: BigUInt
    let reason: LockReason
}

enum LockReason: String, Codable {
    case all = "All"
    case fee = "Fee"
    case misc = "Misc"
}
