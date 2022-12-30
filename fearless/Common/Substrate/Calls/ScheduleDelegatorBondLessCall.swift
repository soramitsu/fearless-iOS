import Foundation
import FearlessUtils
import BigInt

struct ScheduleDelegatorBondLessCall: Codable {
    let candidate: AccountId
    @StringCodable var less: BigUInt
}
