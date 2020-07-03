import Foundation
import BigInt

enum ScaleStringError: Error {
    case unexpectedEncoding
    case unexpectedDecoding
}

extension String: ScaleCodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        guard let data = data(using: .utf8) else {
            throw ScaleStringError.unexpectedEncoding
        }

        try BigUInt(data.count).encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: data)
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let count = Int(try BigUInt(scaleDecoder: scaleDecoder))
        let data = try scaleDecoder.read(count: count)
        try scaleDecoder.confirm(count: count)

        guard let result = String(data: data, encoding: .utf8) else {
            throw ScaleStringError.unexpectedDecoding
        }

        self = result
    }
}
