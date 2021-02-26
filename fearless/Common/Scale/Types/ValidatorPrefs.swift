import Foundation
import FearlessUtils
import BigInt

struct ValidatorPrefs: Codable {
    @StringCodable var commission: BigUInt
}
