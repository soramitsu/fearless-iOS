import Foundation

extension Int16: ScaleEncodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data = Data(bytes: &int, count: MemoryLayout<Int16>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension Int16: ScaleDecodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 2)

        self = Int16(littleEndian: byte.withUnsafeBytes { $0.load(as: Int16.self) })

        try scaleDecoder.confirm(count: 2)
    }
}
