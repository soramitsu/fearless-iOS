import Foundation
import SSFUtils
import BigInt

struct VestingSchedule: Codable {
    let start: UInt32?
    let period: UInt32?
    let periodCount: UInt32?
    @StringCodable var perPeriod: BigUInt
}
