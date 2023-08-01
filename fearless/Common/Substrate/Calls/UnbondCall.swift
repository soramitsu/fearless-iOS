import Foundation
import SSFUtils
import BigInt

struct UnbondCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "value"
    }

    @StringCodable var amount: BigUInt
}
