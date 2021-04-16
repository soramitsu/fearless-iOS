import Foundation
import FearlessUtils

struct PayoutCall: Codable {
    enum CodingKeys: String, CodingKey {
        case validatorStash = "validator_stash"
        case era
    }

    var validatorStash: Data
    @StringCodable var era: EraIndex
}
