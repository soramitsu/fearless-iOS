import Foundation
import FearlessUtils

struct PayoutCall: Codable {
    var validatorStash: Data // TODO: Add conversion from CamelCase to snake_case
    @StringCodable var era: EraIndex
}
