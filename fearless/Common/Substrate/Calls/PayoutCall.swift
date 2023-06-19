import Foundation
import SSFUtils

struct PayoutCall: Codable {
    enum CodingKeys: String, CodingKey {
        case validatorStash = "validator_stash"
        case era
    }

    let validatorStash: Data
    @StringCodable var era: EraIndex
}
