import Foundation
import BigInt
import SSFUtils

struct ParachainSlotLease: Decodable {
    let accountId: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        accountId = try container.decode(AccountId.self)
        amount = try container.decode(StringScaleMapper<BigUInt>.self).value
    }
}
