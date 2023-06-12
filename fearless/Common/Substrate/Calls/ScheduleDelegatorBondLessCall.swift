import Foundation
import SSFUtils
import Web3

struct ScheduleDelegatorBondLessCall: Codable {
    let candidate: AccountId
    @StringCodable var less: BigUInt
}
