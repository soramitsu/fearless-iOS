import Foundation

extension Int32: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        var int = self
        let data: Data = Data(bytes: &int, count: MemoryLayout<Int32>.size)
        scaleEncoder.appendRaw(data: data)
    }
}

extension Int32: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let byte = try scaleDecoder.read(count: 4)

        self = Int32(littleEndian: byte.withUnsafeBytes({ $0.load(as: Int32.self) }))

        try scaleDecoder.confirm(count: 4)
    }
}
