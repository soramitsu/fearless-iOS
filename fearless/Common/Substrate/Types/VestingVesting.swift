import Foundation
import SSFUtils
import BigInt

struct VestingVesting: Codable {
    @OptionStringCodable var locked: BigUInt?
    @OptionStringCodable var perBlock: BigUInt?
    @OptionStringCodable var startingBlock: UInt32?
}
