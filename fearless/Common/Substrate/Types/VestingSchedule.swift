import Foundation
import SSFUtils
import BigInt

struct VestingSchedule: Codable {
    @OptionStringCodable var start: UInt32?
    @OptionStringCodable var period: UInt32?
    @OptionStringCodable var periodCount: UInt32?
    @OptionStringCodable var perPeriod: BigUInt?
}
