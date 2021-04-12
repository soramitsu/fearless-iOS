import Foundation
import FearlessUtils
import BigInt

struct TransferCall: Codable {
    let dest: MultiAddress
    @StringCodable var value: BigUInt
}
