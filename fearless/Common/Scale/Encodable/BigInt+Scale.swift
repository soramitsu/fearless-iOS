import Foundation
import BigInt

private struct EncodingThreshold {
    static let minUInt16: UInt = (1 << 6)
    static let minUInt32: UInt = (1 << 14)
    static let minUIntBig: UInt = (1 << 30)
}

enum ScaleCompactIntError: Error {
    case valueTooLarge
    case unexpectedZeroBytes
}

extension BigUInt: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        let data: Data

        if self < EncodingThreshold.minUInt16 {
            let serialized = Data((self << 2).serialize().reversed())

            if serialized.count == 1 {
                data = serialized
            } else {
                data = Data([0])
            }

        } else if self < EncodingThreshold.minUInt32 {
            data = Data((((self << 2) | 0b01).serialize()).reversed())
        } else if self < EncodingThreshold.minUIntBig {
            var serialized = Data((((self << 2) | 0b10).serialize()).reversed())

            if serialized.count < 4 {
                serialized.append(0)
            }

            data = serialized

        } else {
            let serialized = self.serialize()
            let headerValue = ((serialized.count - 4) << 2) | 0b11

            guard headerValue < 256 else {
                throw ScaleCompactIntError.valueTooLarge
            }

            data = Data(repeating: UInt8(headerValue), count: 1) + Data(serialized.reversed())
        }

        scaleEncoder.appendRaw(data: data)
    }
}

extension BigUInt: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 1)
        let byteValue = UInt8(littleEndian: byte.withUnsafeBytes({ $0.load(as: UInt8.self) }))
        let mode: UInt8 = byteValue & 0b11

        if mode == 0b00 {
            let data = try scaleDecoder.read(count: 1)
            self = BigUInt(data) >> 2
            try scaleDecoder.confirm(count: 1)
        } else if mode == 0b01 {
            let data = try scaleDecoder.read(count: 2)
            self = BigUInt(Data(data.reversed())) >> 2
            try scaleDecoder.confirm(count: 2)
        } else if mode == 0b10 {
            let data = try scaleDecoder.read(count: 4)
            self = BigUInt(Data(data.reversed())) >> 2
            try scaleDecoder.confirm(count: 4)
        } else {
            let header = try scaleDecoder.read(count: 1)
            let headerValue = UInt8(littleEndian: header.withUnsafeBytes({ $0.load(as: UInt8.self) }))
            let count = (headerValue >> 2) + 4
            try scaleDecoder.confirm(count: 1)

            guard count > 0 else {
                throw ScaleCompactIntError.unexpectedZeroBytes
            }

            let data = try scaleDecoder.read(count: Int(count))
            self = BigUInt(Data(data.reversed()))
            try scaleDecoder.confirm(count: Int(count))
        }
    }
}
