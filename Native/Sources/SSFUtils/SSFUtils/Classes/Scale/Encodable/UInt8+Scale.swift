import Foundation

extension UInt8: ScaleEncodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data = Data(bytes: &int, count: MemoryLayout<UInt8>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension UInt8: ScaleDecodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 1)

        self = UInt8(littleEndian: byte.withUnsafeBytes { $0.load(as: UInt8.self) })

        try scaleDecoder.confirm(count: 1)
    }
}
