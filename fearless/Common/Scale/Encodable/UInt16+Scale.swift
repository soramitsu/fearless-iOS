import Foundation

extension UInt16: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<UInt16>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension UInt16: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 2)

        self = UInt16(littleEndian: byte.withUnsafeBytes({ $0.load(as: UInt16.self) }))

        try scaleDecoder.confirm(count: 2)
    }
}
