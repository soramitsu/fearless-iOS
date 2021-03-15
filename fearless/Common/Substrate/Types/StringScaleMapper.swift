import Foundation

struct StringScaleMapper<T: LosslessStringConvertible & Equatable>: Decodable, Equatable {
    let value: T

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let strValue = try container.decode(String.self)

        guard let convertedValue = T(strValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Can't decode value: \(strValue)")
        }

        self.value = convertedValue
    }
}
