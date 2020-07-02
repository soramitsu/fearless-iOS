import Foundation
import BigInt

extension Int8: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<Int8>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension Int8: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 1)

        self = Int8(littleEndian: byte.withUnsafeBytes({ $0.load(as: Int8.self) }))

        try scaleDecoder.confirm(count: 1)
    }
}
