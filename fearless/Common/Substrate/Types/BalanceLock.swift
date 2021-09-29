import Foundation
import BigInt
import FearlessUtils

struct BalanceLock: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case amount
        case reasons
    }

    let identifier: String
    @StringCodable var amount: BigUInt
    let reasons: LockReason
}

enum LockReason: String, Codable {
    case all = "All"
    case fee = "Fee"
    case misc = "Misc"
}
