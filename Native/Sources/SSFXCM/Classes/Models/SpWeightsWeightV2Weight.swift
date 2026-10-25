import BigInt
import Foundation
import SSFUtils

struct SpWeightsWeightV3Weight: Codable {
    @StringCodable var refTime: BigUInt
    @StringCodable var proofSize: BigUInt
}

extension SpWeightsWeightV3Weight: Equatable {}
