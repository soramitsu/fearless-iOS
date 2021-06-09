import Foundation

@propertyWrapper
public struct BytesCodable: Codable, Equatable {
    public var wrappedValue: Data

    public init(wrappedValue: Data) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)

        wrappedValue = Data(byteArray.map(\.value))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let bytes = wrappedValue.map { StringScaleMapper(value: $0) }

        try container.encode(bytes)
    }
}
