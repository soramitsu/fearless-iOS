import BigInt

public struct RuntimeDispatchInfo: Codable, Equatable {
    let inclusionFee: FeeDetails

    public init(inclusionFee: FeeDetails) {
        self.inclusionFee = inclusionFee
    }

    public var fee: String {
        "\(inclusionFee.baseFee + inclusionFee.lenFee + inclusionFee.adjustedWeightFee)"
    }

    public var feeValue: BigUInt {
        BigUInt(stringLiteral: fee)
    }
}

public struct FeeDetails: Codable, Equatable {
    let baseFee: BigUInt
    let lenFee: BigUInt
    let adjustedWeightFee: BigUInt

    public init(
        baseFee: BigUInt,
        lenFee: BigUInt,
        adjustedWeightFee: BigUInt
    ) {
        self.baseFee = baseFee
        self.lenFee = lenFee
        self.adjustedWeightFee = adjustedWeightFee
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let baseFeeHex = try container.decode(String.self, forKey: .baseFee)
        let lenFeeHex = try container.decode(String.self, forKey: .lenFee)
        let adjustedWeightFeeHex = try container.decode(String.self, forKey: .adjustedWeightFee)

        baseFee = BigUInt.fromHexString(baseFeeHex) ?? BigUInt.zero
        lenFee = BigUInt.fromHexString(lenFeeHex) ?? BigUInt.zero
        adjustedWeightFee = BigUInt.fromHexString(adjustedWeightFeeHex) ?? BigUInt.zero
    }
}
