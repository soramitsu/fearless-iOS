import Foundation
import SSFUtils
import BigInt

struct ValidatorExposure: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    let others: [IndividualExposure]
}

struct IndividualExposure: Codable {
    var who: Data
    @StringCodable var value: BigUInt
}
