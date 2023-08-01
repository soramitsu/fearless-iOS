import Foundation
import BigInt

struct FeeDetails: Codable {
    let baseFee: BigUInt
    let lenFee: BigUInt
    let adjustedWeightFee: BigUInt

    init(
        baseFee: BigUInt,
        lenFee: BigUInt,
        adjustedWeightFee: BigUInt
    ) {
        self.baseFee = baseFee
        self.lenFee = lenFee
        self.adjustedWeightFee = adjustedWeightFee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let baseFeeHex = try container.decode(String.self, forKey: .baseFee)
        let lenFeeHex = try container.decode(String.self, forKey: .lenFee)
        let adjustedWeightFeeHex = try container.decode(String.self, forKey: .adjustedWeightFee)

        baseFee = BigUInt.fromHexString(baseFeeHex) ?? BigUInt.zero
        lenFee = BigUInt.fromHexString(lenFeeHex) ?? BigUInt.zero
        adjustedWeightFee = BigUInt.fromHexString(adjustedWeightFeeHex) ?? BigUInt.zero
    }
}

struct RuntimeDispatchInfo: Codable {
    let inclusionFee: FeeDetails

    var fee: String {
        "\(inclusionFee.baseFee + inclusionFee.lenFee + inclusionFee.adjustedWeightFee)"
    }
}
