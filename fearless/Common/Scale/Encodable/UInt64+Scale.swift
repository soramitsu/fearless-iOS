import Foundation

extension UInt64: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<UInt64>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension UInt64: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 8)

        self = UInt64(littleEndian: byte.withUnsafeBytes({ $0.load(as: UInt64.self) }))

        try scaleDecoder.confirm(count: 8)
    }
}
