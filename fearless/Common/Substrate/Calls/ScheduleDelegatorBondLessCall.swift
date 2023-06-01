import Foundation
import SSFUtils
import BigInt

struct ScheduleDelegatorBondLessCall: Codable {
    let candidate: AccountId
    @StringCodable var less: BigUInt
}
