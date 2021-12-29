import Foundation
import FearlessUtils
import BigInt

struct ValidatorExposure: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    let others: [IndividualExposure]
}

struct IndividualExposure: Codable {
    @BytesCodable var who: Data
    @StringCodable var value: BigUInt
}
