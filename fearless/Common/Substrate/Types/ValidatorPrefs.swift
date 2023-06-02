import Foundation
import SSFUtils
import BigInt

struct ValidatorPrefs: Codable, Equatable {
    @StringCodable var commission: BigUInt
    let blocked: Bool
}
