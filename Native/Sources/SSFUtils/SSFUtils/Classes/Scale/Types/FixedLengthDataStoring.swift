import Foundation

public protocol FixedLengthDataStoring: Codable, ScaleCodable {
    static var length: Int { get }
    var value: Data { get }

    init(value: Data)
}

public extension FixedLengthDataStoring {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)

        guard data.count == Self.length else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "incorrect data length"
            )
        }

        self.init(value: data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let data = try scaleDecoder.readAndConfirm(count: Self.length)

        self.init(value: data)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: value)
    }
}
