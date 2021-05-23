import Foundation
import FearlessUtils
import BigInt

struct ValidatorExposure: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    let others: [IndividualExposure]
}

struct IndividualExposure: Codable {
    let who: Data
    @StringCodable var value: BigUInt
}

extension ValidatorExposure {
    func clippedNominators(for limit: UInt32) -> [IndividualExposure] {
        Array(others.sorted(by: { $0.value > $1.value }).prefix(Int(limit)))
    }
}
