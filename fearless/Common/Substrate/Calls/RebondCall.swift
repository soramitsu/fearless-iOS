import Foundation
import SSFUtils
import BigInt

struct RebondCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "value"
    }

    @StringCodable var amount: BigUInt
}
