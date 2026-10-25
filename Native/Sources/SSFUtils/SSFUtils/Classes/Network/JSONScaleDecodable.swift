import Foundation

public struct JSONScaleDecodable<T: ScaleDecodable>: Decodable {
    public let underlyingValue: T?

    public init(value: T?) {
        underlyingValue = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            underlyingValue = nil
        } else {
            let value = try container.decode(String.self)
            let data = try Data(hexStringSSF: value)
            let scaleDecoder = try ScaleDecoder(data: data)
            underlyingValue = try T(scaleDecoder: scaleDecoder)
        }
    }
}
