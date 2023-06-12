import Foundation
import SSFUtils
import Web3

struct BondExtraCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "max_additional"
    }

    @StringCodable var amount: BigUInt
}
