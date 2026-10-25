import BigInt
import Foundation

public enum BitVecNodeError: Error {
    case expectedArrayOfBools(json: JSON)
    case expectedCompactBitLength
    case expectedHex
}

public class BitVecNode: Node {
    public var typeName: String { GenericType.bitVec.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let array = value.arrayValue else {
            throw BitVecNodeError.expectedArrayOfBools(json: value)
        }

        let bits: [Bool] = try array.map { json in
            guard let boolValue = json.boolValue else {
                throw BitVecNodeError.expectedArrayOfBools(json: value)
            }

            return boolValue
        }

        let length = bits.count

        try encoder.append(encodable: BigUInt(length))

        let value = bits.enumerated().reduce(BigUInt(0)) { result, item in
            if item.element {
                return result | (BigUInt(1) << item.offset)
            } else {
                return result
            }
        }

        var data: [UInt8] = value.serialize().reversed()

        let byteLength = sizeOfBytes(bitsCount: length)

        while data.count < byteLength {
            data.append(0)
        }

        try encoder.appendBytes(json: .stringValue(Data(data).toHex(includePrefix: true)))
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let bytesCountStr = try decoder.readCompact(type: PrimitiveType.u32.name).stringValue,
              let bitCount = Int(bytesCountStr) else
        {
            throw BitVecNodeError.expectedCompactBitLength
        }

        let bytesCount = sizeOfBytes(bitsCount: bitCount)

        guard let hex = try decoder.readBytes(length: bytesCount).stringValue else {
            throw BitVecNodeError.expectedHex
        }

        let data = try Data(hexStringSSF: hex)
        let value = BigUInt(Data(data.reversed()))

        let bits: [JSON] = (0 ..< bitCount).map { index in
            let mask = BigUInt(1) << index

            if (value & mask) == 0 {
                return JSON.boolValue(false)
            } else {
                return JSON.boolValue(true)
            }
        }

        return .arrayValue(bits)
    }

    private func sizeOfBytes(bitsCount: Int) -> Int {
        (bitsCount / 8) + (bitsCount % 8 > 0 ? 1 : 0)
    }
}
