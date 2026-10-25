import BigInt
import Foundation
import IrohaCrypto
import SSFUtils

public final class SubstrateJunctionFactory: JunctionFactory {
    static let chaincodeLength = 32

    override public init() {
        super.init()
    }

    override func createChaincodeFromJunction(
        _ junction: String,
        type: ChaincodeType
    ) throws -> Chaincode {
        var serialized = try serialize(junction: junction)

        if serialized.count < Self.chaincodeLength {
            serialized += Data(repeating: 0, count: Self.chaincodeLength - serialized.count)
        }

        if serialized.count > Self.chaincodeLength {
            serialized = try serialized.blake2b32()
        }

        return Chaincode(data: serialized, type: type)
    }

    private func serialize(junction: String) throws -> Data {
        if let number = BigUInt(junction) {
            return Data(number.serialize().reversed())
        }

        if let data = try? Data(hexStringSSF: junction) {
            return data
        }

        let encoder = ScaleEncoder()
        try junction.encode(scaleEncoder: encoder)

        return encoder.encode()
    }
}
