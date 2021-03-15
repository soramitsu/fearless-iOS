import Foundation
import FearlessUtils
import BigInt

struct ValidatorPrefs: Codable, Equatable {
    @StringCodable var commission: BigUInt
}
