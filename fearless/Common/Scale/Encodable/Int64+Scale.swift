import Foundation

extension Int64: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<Int64>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension Int64: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 8)

        self = Int64(littleEndian: byte.withUnsafeBytes({ $0.load(as: Int64.self) }))

        try scaleDecoder.confirm(count: 8)
    }
}
