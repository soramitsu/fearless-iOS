import Foundation
import FearlessUtils
import BigInt

struct TreasuryDepositEvent: Decodable {
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()
        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
