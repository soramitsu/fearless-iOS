import Foundation

extension UInt32: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<UInt32>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension UInt32: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 4)

        self = UInt32(littleEndian: byte.withUnsafeBytes({ $0.load(as: UInt32.self) }))

        try scaleDecoder.confirm(count: 4)
    }
}
