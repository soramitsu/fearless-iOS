import Foundation
import SSFUtils
import Web3

struct BalanceDepositEvent: Decodable {
    let accountId: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        accountId = try unkeyedContainer.decode(AccountId.self)
        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
